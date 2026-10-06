package jp.co.misumi.xxx.event;

import jp.co.misumi.fw.event.api.consumer.MisumiFwEventAPIConsumerConfigurationDefaults;
import jp.co.misumi.fw.event.api.consumer.application.AbstractEventConsumerApplication;
import jp.co.misumi.fw.event.api.consumer.command.MisumiEventConsumerCommand;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import picocli.CommandLine;

@SpringBootApplication
public class Application extends AbstractEventConsumerApplication {

  public Application(
      CommandLine.IFactory factory,
      MisumiEventConsumerCommand command,
      MisumiEventConsumerCommand.Run runSubCommand,
      Environment environment) {
    super(factory, command, runSubCommand, environment);
  }

  public static void main(String[] args) {
    System.exit(SpringApplication.exit(SpringApplication.run(Application.class, args)));
  }

  @Configuration
  public static class MisumiFwConfiguration
      implements MisumiFwEventAPIConsumerConfigurationDefaults {}
}
