package jp.co.misumi.xxx.async;

import jp.co.misumi.fw.async.api.consumer.MisumiFwAsyncAPIConsumerConfigurationDefaults;
import jp.co.misumi.fw.async.api.consumer.application.AbstractAsyncConsumerApplication;
import jp.co.misumi.fw.async.api.consumer.command.MisumiAsyncConsumerCommand;
import jp.co.misumi.fw.rest.api.client.MisumiFwRestAPIClientConfigurationDefaults;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import picocli.CommandLine;

@SpringBootApplication
public class Application extends AbstractAsyncConsumerApplication {

  public Application(
      CommandLine.IFactory factory,
      MisumiAsyncConsumerCommand command,
      MisumiAsyncConsumerCommand.Run runSubCommand,
      Environment environment) {
    super(factory, command, runSubCommand, environment);
  }

  public static void main(String[] args) {
    System.exit(SpringApplication.exit(SpringApplication.run(Application.class, args)));
  }

  @Configuration
  public static class MisumiFwConfiguration
      implements MisumiFwAsyncAPIConsumerConfigurationDefaults,
      MisumiFwRestAPIClientConfigurationDefaults {
  }
}
