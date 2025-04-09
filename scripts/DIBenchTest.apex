@IsTest
public with sharing class DIBenchTest {
  @IsTest
  static void test_performance_5_25() {
    DI.ServiceCollection services = DI.services();

    Integer startCPU = Limits.getCpuTime();
    for (Integer i = 1; i <= 105; i++) {
      services.addTransient('DIBenchClass.Benchmark' + i);
    }
    Integer endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Registration Performance (CPU): ' + (endCPU - startCPU));

    DI.ServiceProvider provider = services.buildServiceProvider();

    startCPU = Limits.getCpuTime();
    for (Integer i = 1; i <= 5; i++) {
      Object service = provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution Performance (CPU) x5: ' + (endCPU - startCPU));

    startCPU = Limits.getCpuTime();
    for (Integer i = 6; i <= 15; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution Performance (CPU) 10: ' + (endCPU - startCPU));

    startCPU = Limits.getCpuTime();
    for (Integer i = 16; i <= 30; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution Performance (CPU) 15: ' + (endCPU - startCPU));

    startCPU = Limits.getCpuTime();
    for (Integer i = 31; i <= 50; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution Performance (CPU) 20: ' + (endCPU - startCPU));

    startCPU = Limits.getCpuTime();
    for (Integer i = 51; i <= 75; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution Performance (CPU) 25: ' + (endCPU - startCPU));


    startCPU = Limits.getCpuTime();
    for (Integer i = 1; i <= 5; i++) {
      Object service = provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution 2nd Round (CPU) x5: ' + (endCPU - startCPU));

    startCPU = Limits.getCpuTime();
    for (Integer i = 6; i <= 15; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution 2nd Round (CPU) 10: ' + (endCPU - startCPU));

    startCPU = Limits.getCpuTime();
    for (Integer i = 16; i <= 30; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution 2nd Round (CPU) 15: ' + (endCPU - startCPU));

    startCPU = Limits.getCpuTime();
    for (Integer i = 31; i <= 50; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution 2nd Round (CPU) 20: ' + (endCPU - startCPU));

    startCPU = Limits.getCpuTime();
    for (Integer i = 51; i <= 75; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution 2nd Round (CPU) 25: ' + (endCPU - startCPU));
  }

  @IsTest
  static void test_performance_30_40() {
    DI.ServiceCollection services = DI.services();

    Integer startCPU = Limits.getCpuTime();
    for (Integer i = 1; i <= 105; i++) {
      services.addTransient('DIBenchClass.Benchmark' + i);
    }
    Integer endCPU = Limits.getCpuTime();
    // System.debug(LoggingLevel.INFO,'DI Registration Performance (CPU): ' + (endCPU - startCPU));

    DI.ServiceProvider provider = services.buildServiceProvider();

    startCPU = Limits.getCpuTime();
    for (Integer i = 1; i <= 30; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution Performance (CPU) 30: ' + (endCPU - startCPU));

    // 35
    startCPU = Limits.getCpuTime();
    for (Integer i = 31; i <= 65; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution Performance (CPU) 35: ' + (endCPU - startCPU));

    // 40
    startCPU = Limits.getCpuTime();
    for (Integer i = 66; i <= 105; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution Performance (CPU) 40: ' + (endCPU - startCPU));

    startCPU = Limits.getCpuTime();
    for (Integer i = 1; i <= 30; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution 2nd Round (CPU) 30: ' + (endCPU - startCPU));

    // 35
    startCPU = Limits.getCpuTime();
    for (Integer i = 31; i <= 65; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution 2nd Round (CPU) 35: ' + (endCPU - startCPU));

    // 40
    startCPU = Limits.getCpuTime();
    for (Integer i = 66; i <= 105; i++) {
      provider.getService('DIBenchClass.Benchmark' + i);
    }
    endCPU = Limits.getCpuTime();
    System.debug(LoggingLevel.INFO,'DI Resolution 2nd Round (CPU) 40: ' + (endCPU - startCPU));
  }
  // #endregion
  // ==================
}
