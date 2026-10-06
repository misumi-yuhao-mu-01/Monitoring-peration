package jp.co.misumi.xxx.rest;

import jp.co.misumi.fw.async.api.producer.MisumiFwAsyncAPIProducerConfigurationDefaults;
import jp.co.misumi.fw.event.api.producer.MisumiFwEventAPIProducerConfigurationDefaults;
import jp.co.misumi.fw.rest.api.server.MisumiFwRestAPIServerConfigurationDefaults;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Configuration;

@SpringBootApplication
public class Application {

  public static void main(String[] args) {
    SpringApplication.run(Application.class);
  }

  @Configuration
  public static class MisumiFwConfiguration
      implements MisumiFwRestAPIServerConfigurationDefaults,
          MisumiFwEventAPIProducerConfigurationDefaults,
          MisumiFwAsyncAPIProducerConfigurationDefaults {}
}
