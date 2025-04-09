@IsTest
public with sharing class DIBenchTest {
  @IsTest
  static void test_performance() {
    DI.ServiceCollection services = DI.services();

    Datetime startTime = Datetime.now();
    Integer startCPU = Limits.getCpuTime();
    for (Integer i = 1; i <= 100; i++) {
      services.addTransient('DIBenchClass.Benchmark' + i);
    }
    Datetime endTime = Datetime.now();
    Integer endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,
      'DI Registration Performance (Time): ' +
      (endTime.getTime() - startTime.getTime())
    );
    System.debug(LoggingLevel.INFO,'DI Registration Performance (CPU): ' + (endCPU - startCPU));

    DI.ServiceProvider provider = services.buildServiceProvider();

    startTime = Datetime.now();
    startCPU = Limits.getCpuTime();
    for (Integer i = 1; i <= 100; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endTime = Datetime.now();
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,
      'DI Resolution Performance (Time): ' +
      (endTime.getTime() - startTime.getTime())
    );
    System.debug(LoggingLevel.INFO,'DI Resolution Performance (CPU): ' + (endCPU - startCPU));

    startTime = Datetime.now();
    startCPU = Limits.getCpuTime();
    for (Integer i = 1; i <= 100; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endTime = Datetime.now();
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,
      'DI Resolution Performance (Time): ' +
      (endTime.getTime() - startTime.getTime())
    );
    System.debug(LoggingLevel.INFO,'DI Resolution Performance (CPU): ' + (endCPU - startCPU));
  }
  // #endregion
  // ==================
}
