package jp.co.misumi.xxx.batch.command;

import javax.inject.Named;
import jp.co.misumi.fw.core.cli.AbstractCliCommand;
import picocli.CommandLine;

@Named
@CommandLine.Command(
    name = "YOUR_COMMAND_NAME",
    mixinStandardHelpOptions = true,
    versionProvider = XxxCommand.class,
    description = "misumi-fw batch sample")
public class XxxCommand extends AbstractCliCommand {}
