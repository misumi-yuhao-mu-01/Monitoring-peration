package jp.co.misumi.xxx.async;

import org.springframework.boot.context.TypeExcludeFilter;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.FilterType;

@Configuration(proxyBeanMethods = false)
@ComponentScan(
    basePackages = {
      "jp.co.misumi.xxx.domain",
      "jp.co.misumi.xxx.client",
      "jp.co.misumi.xxx.store"
    },
    excludeFilters = {
      @ComponentScan.Filter(type = FilterType.CUSTOM, value = TypeExcludeFilter.class)
    })
public class XxxAsyncConsumerConfiguration {}
