# k8s-spring-cloud
### 所有等SpringCloud 微服务的k8s的配置文件个别参数不一样，生产环境可以使用helm部署,所有的配置均支持环境变量配置
### 开发人员对版本进行升级可以使用idea 生成镜像并把镜像推到注册中心，生产环境去注册中心拉取镜像升级deployment
### 使用initContainers控制启动顺序

## 
```text
SpringCloud 微服务通过feign来完成服务间的调用，根据服务名称去注册中心找所有该名称的服务列表。
如果用户配置了负载均衡，则使用该规则选取一个服务，

调用时获取该服务的ip和端口来完成调用，这里就有个问题。譬如，服务器上的微服务为docker,本机开发测试不能访问docker的IP，本人通过配置hosts解决。
上了k8s之后，k8s有自己的负载均衡，SpringCloud就没有必要再进行负载均衡了，feign使用url进行配置，并支持环境变量传入服务端点，
这样开发环境配置环境变量也可以调用微服务了，生产环境docker compose,docker swarm, k8s一样可以用环境变量配置。

生产环境只需把网关服务暴露出去并配置https就OK了。

所有日志统一放到同一个目录下面使用filebeat统一收集，日志收集目录必须和环境变量LOG_DIR一致

具体配置如下。
```
```java
/**
 * minio文件管理微服务
 *
 * @author luchaoxin
 * @date 2018/6/28
 */
@FeignClient(contextId = "remoteMinioService", value = ServiceNameConstants.MINIO_SERVICE,
		path = "/minio",
		//k8s部署时只需配置环境变量MINIO_ENDPOINT就可以调用服务了
		url = "http://${MINIO_ENDPOINT:datainsights-minio-endpoint:3333}")
public interface RemoteMinioService {

	/**
	 * @param md5        文件md5
	 * @param fileName   文件名称
	 * @param identifier 文件identifier 通过该字段去minio获取文件
	 * @return
	 */
	@GetMapping("/checkout")
	R<ChunkInfo> checkFile(@RequestParam("md5") String md5,
						   @RequestParam(value = "fileName", required = false) String fileName,
						   @RequestParam(value = "identifier", required = false) String identifier
	);

	@PostMapping("/upload")
	R upload(@Valid @CustomParamBinding FileInfo fileInfo) throws Exception;

	/**
	 * 有权限获取视频分流
	 *
	 * @param bucketName
	 * @param objectName
	 * @param headers
	 * @return
	 * @throws Exception
	 */
	@RequestMapping(value = "/{bucketName}/{objectName}", method = RequestMethod.GET)
	ResponseEntity<ResourceRegion> getVideo(@PathVariable("bucketName") String bucketName,
											@PathVariable("objectName") String objectName,
											@RequestParam("type") String type,
											@RequestHeader HttpHeaders headers) throws Exception;

	@PostMapping("/")
	void putObject(@RequestBody FileEntry fileEntry) throws Exception;

	@RequestMapping(value = "/{bucketName}", method = RequestMethod.GET)
	R<FileEntry> getObject(@PathVariable("bucketName") String bucketName,
						   @RequestParam("objectName") String objectName) throws IOException;

	@RequestMapping(value = "/public/{bucketName}", method = RequestMethod.GET)
	R<FileEntry> getPublicObject(@PathVariable("bucketName") String bucketName,
								 @RequestParam("objectName") String objectName) throws IOException;

	@ResponseStatus(HttpStatus.ACCEPTED)
	@DeleteMapping("/{bucketName}/{objectName}/")
	void removeObject(@PathVariable("bucketName") String bucketName,
					  @PathVariable("objectName") String objectName);
}
```
# SpringCloud 可以有两份配置文件一份为公共配置文件application-dev.yml，还有一份自己的配置datainsights-minio-endpoint-dev.yml
每一个微服务只有resources目录下只有bootstrap.yml
配置如下
```yaml
server:
  port: ${SERVER_PORT:3333}

spring:
  mvc:
    view:
      prefix: classpath:/templates/
      suffix: .html
    static-path-pattern: /static/**
  servlet:
    multipart:
      max-file-size: 300MB
      max-request-size: 400MB
  application:
    name: datainsights-minio-endpoint
  cloud:
    nacos:
      discovery:
        server-addr: ${NACOS_ENDPOINT:datainsights-register:8848}
        cluster-name: ${CLOUD_CLUSTER:DEFAULT}
      config:
        server-addr: ${spring.cloud.nacos.discovery.server-addr} # 此配置等于${NACOS_ENDPOINT:datainsights-register:8848}
        file-extension: yml
        shared-dataids: application-${spring.profiles.active}.${spring.cloud.nacos.config.file-extension} #此配置等于application-dev.yaml
  profiles:
    active: dev
  autoconfigure:
    exclude: org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration
```

### 配置中心中的配置文件application-dev.yaml如下
```yaml
# 加解密根密码
jasypt:
  encryptor:
    password: ${JASYPT_PWD:hello}
# redis 相关
spring:
  cloud:
    sentinel:
      transport:
        dashboard: ${SENTINEL_DASHBOARD_ENDPOINT:192.168.31.90:30888}
      datasource:
        ds:
          nacos:
            server-addr: ${spring.cloud.nacos.discovery.server-addr}
            data-id: ${spring.application.name}-sentinel
            group-id: ${spring.cloud.nacos.discovery.cluster-name}
            rule-type: FLOW
  zipkin:
    base-url: http://${ZIPKIN_ENDPOINT:192.168.31.90:30411}
  sleuth:
    sampler:
      percentage: 1
  redis:
    password: ${REDIS_PWD:我是密码}
    host: ${REDIS_HOST:我是IP:30637}
    port: ${REDIS_PORT:6379}
  tx-manager:
    endpoint: ${TX_MANAGER_ENDPOINT:192.168.31.90:5004}
    load-balancer: ${TX_MANAGER_LOAD_BALANCE:false}
  log:
    dir: ${LOG_DIR:/var/datainsights-log}

# 暴露监控端点
management:
  endpoints:
    web:
      exposure:
        include: '*'

# feign 配置
feign:
  hystrix:
    enabled: true
  okhttp:
    enabled: true
  httpclient:
    enabled: false
  client:
    config:
      default:
        connectTimeout: 10000
        readTimeout: 10000
  compression:
    request:
      enabled: true
    response:
      enabled: true
# hystrix If you need to use ThreadLocal bound variables in your RequestInterceptor`s
# you will need to either set the thread isolation strategy for Hystrix to `SEMAPHORE or disable Hystrix in Feign.
hystrix:
  command:
    default:
      execution:
        isolation:
          strategy: SEMAPHORE
          thread:
            timeoutInMilliseconds: 60000
  shareSecurityContext: true

#请求处理的超时时间
ribbon:
  ReadTimeout: 10000
  ConnectTimeout: 10000

# mybaits-plus配置
mybatis-plus:
  # MyBatis Mapper所对应的XML文件位置
  mapper-locations: classpath:/mapper/*Mapper.xml
  global-config:
    # 关闭MP3.0自带的banner
    banner: false
    enable-sql-runner: true
    db-config:
      # 主键类型
      id-type: auto
## spring security 配置
security:
  oauth2:
    client:
      # 默认放行url,如果子模块重写这里的配置就会被覆盖
      ignore-urls:
        - /actuator/**
        - /v2/api-docs
    resource:
      loadBalanced: true
      token-info-uri: http://${AUTH2_ENDPOINT:datainsights-auth:3000}/oauth/check_token
```
### 微服务datainsights-minio-endpoint自己的那一份配置在配置中心nacos之中配置如下
```yaml
## spring security 配置
security:
  oauth2:
    client:
      client-id: ${CLIENT_ID:ENC(client-id)}
      client-secret:${CLIENT_SECRET:ENC(client-secret)}
      scope: server
      ignore-urls:
        - /actuator/**
        - /v2/api-docs
      resource:
      token-info-uri: http://${AUTH_ENFDPOINT:datainsights-auth:3000}/oauth/check_token
# 文件系统 
minio:
  url: https://${MINIO_ENDPOINT:minio.datainsights.biz}
  access-key: ${MINIO_ACCESS_KEY:ENC(加密密码)}
  secret-key: ${MINIO_SECRET_KEY:ENC(加密密码)}
```


