package jp.co.misumi.xxx.batch;

import jp.co.misumi.fw.batch.MisumiFwBatchConfigurationDefaults;
import jp.co.misumi.fw.batch.application.AbstractBatchApplication;
import jp.co.misumi.fw.batch.job.domain.JobRepository;
import jp.co.misumi.xxx.batch.command.XxxCommand;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Configuration;
import picocli.CommandLine;

@SpringBootApplication
public class Application extends AbstractBatchApplication {
  public Application(
      CommandLine.IFactory factory, JobRepository jobRepository, XxxCommand xxxCommand) {
    super(factory, jobRepository, xxxCommand);
  }

  public static void main(String[] args) {
    System.exit(SpringApplication.exit(SpringApplication.run(Application.class, args)));
  }

  @Configuration
  public static class MisumiFwConfiguration implements MisumiFwBatchConfigurationDefaults {}
}
