DI.ServiceProvider providerA = DI.services()
    .load('GroupA')
    .addSingleton('DITest.IUtility', 'DITest.Utility')
    .addScoped('DITest.ILogger', 'DITest.TableLogger')
    .addTransient('DITest.IAccountService', 'DITest.AccountService')
    .buildServiceProvider();


DI.ServiceProvider providerA = DI.services()
    .load('GroupA')
    .buildServiceProvider();


public class ModuleA extends DI.Module {
    protected override void configure(DI.ServiceCollection services) {
        services
            .load('GroupA')
            .addSingleton('DITest.IUtility', 'DITest.Utility')
            .addScoped('DITest.ILogger', 'DITest.TableLogger')
            .addTransient('DITest.IAccountService', 'DITest.AccountService');
    }
}
