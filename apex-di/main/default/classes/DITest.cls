/**
 * Copyright 2020 Jeff Jin
 * https://github.com/apexfarm/ApexDI
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions ands
 * limitations under the License.
 */

@IsTest
public class DITest {
    @IsTest
    static void test_nonfunction_for_coverage() {
        DI.ServiceCacheKey key1 = new DI.ServiceCacheKey('DITest.IUtility');
        DI.ServiceCacheKey key2 = new DI.ServiceCacheKey('DITest.IUtility');
        Assert.areEqual(key1, key2);
        Assert.areEqual(key1.hashCode(), key2.hashCode());
    }

    // ================
    // #region Services

    @IsTest
    static void test_services_lifetime() {
        DI.ServiceProvider providerA = DI.services()
            .addSingleton('DITest.IUtility', 'DITest.Utility')
            .addScoped('DITest.ILogger', 'DITest.TableLogger')
            .addTransient('DITest.IAccountService', 'DITest.AccountService')
            .buildServiceProvider();

        DI.ServiceProvider providerB = DI.services()
            .addSingleton('DITest.IUtility', 'DITest.Utility')
            .addScoped('DITest.ILogger', 'DITest.TableLogger')
            .addTransient('DITest.IAccountService', 'DITest.AccountService')
            .buildServiceProvider();

        // Singleton
        Assert.areNotEqual(null, providerA.getService(IUtility.class));
        Assert.areNotEqual(null, providerB.getService(IUtility.class));
        Assert.areEqual(providerA.getService(IUtility.class), providerA.getService(IUtility.class));
        Assert.areEqual(providerB.getService(IUtility.class), providerB.getService(IUtility.class));
        Assert.areEqual(providerA.getService(IUtility.class), providerB.getService(IUtility.class));
        Assert.areEqual(providerA.getService(IUtility.class), providerA.getService('DITest.IUtility'));
        Assert.areEqual(providerB.getService(IUtility.class), providerB.getService('DITest.IUtility'));
        Assert.areEqual(providerA.getService(IUtility.class), providerB.getService('DITest.IUtility'));

        Assert.areNotEqual(null, providerA.getService(ILogger.class));
        Assert.areNotEqual(null, providerB.getService(ILogger.class));
        Assert.areEqual(providerA.getService(ILogger.class), providerA.getService(ILogger.class));
        Assert.areEqual(providerB.getService(ILogger.class), providerB.getService(ILogger.class));
        Assert.areNotEqual(providerA.getService(ILogger.class), providerB.getService(ILogger.class));

        Assert.areNotEqual(null, providerA.getService(IAccountService.class));
        Assert.areNotEqual(null, providerB.getService(IAccountService.class));
        Assert.areNotEqual(providerA.getService(IAccountService.class), providerA.getService(IAccountService.class));
        Assert.areNotEqual(providerB.getService(IAccountService.class), providerB.getService(IAccountService.class));
        Assert.areNotEqual(providerA.getService(IAccountService.class), providerB.getService(IAccountService.class));
    }

    @IsTest
    static void test_services_lifetime_singleton_caveat() {
        // Provider A
        DI.ServiceProvider providerA = DI.services()
            .addSingleton('DITest.IUtility', 'DITest.Utility')
            .buildServiceProvider();

        IUtility util = (IUtility) providerA.getService(IUtility.class);
        Assert.isTrue(util instanceof Utility);

        // Provider B
        DI.ServiceProvider providerB = DI.services()
            .addSingleton('DITest.IUtility', 'DITest.AnotherUtility')
            .buildServiceProvider();

        IUtility anotherUtil = (IUtility) providerB.getService(IUtility.class);
        Assert.isFalse(anotherUtil instanceof AnotherUtility);
        Assert.areEqual(anotherUtil, util);

        // Provider C
        DI.ServiceProvider providerC = DI.services()
            .addScoped('DITest.IUtility', 'DITest.AnotherUtility')
            .buildServiceProvider();

        IUtility anotherUtil2 = (IUtility) providerC.getService(IUtility.class);
        Assert.isTrue(anotherUtil2 instanceof AnotherUtility);
        Assert.isTrue(anotherUtil2 != util);
    }

    @IsTest
    static void test_services_concrete_types() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.TableLogger')
            .addScoped('DITest.EmailLogger')
            .addTransient('DITest.AWSS3Logger')
            .buildServiceProvider();

        ILogger tableLogger = (ILogger) provider.getService(TableLogger.class);
        ILogger emailLogger = (ILogger) provider.getService(EmailLogger.class);
        ILogger awss3Logger = (ILogger) provider.getService(AWSS3Logger.class);

        Assert.isTrue(awss3Logger instanceof AWSS3Logger);
        Assert.isTrue(emailLogger instanceof EmailLogger);
        Assert.isTrue(tableLogger instanceof TableLogger);
    }

    @IsTest
    static void test_services_instances() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.TableLogger', new TableLogger())
            .addScoped('DITest.EmailLogger', new EmailLogger())
            .addTransient('DITest.AWSS3Logger', new AWSS3Logger())
            .buildServiceProvider();

        ILogger tableLogger = (ILogger) provider.getService(TableLogger.class);
        ILogger emailLogger = (ILogger) provider.getService(EmailLogger.class);
        ILogger awss3Logger = (ILogger) provider.getService(AWSS3Logger.class);

        Assert.isTrue(tableLogger instanceof TableLogger);
        Assert.isTrue(emailLogger instanceof EmailLogger);
        Assert.isTrue(awss3Logger instanceof AWSS3Logger);
    }

    @IsTest
    static void test_serviceProvider() {
        DI.ServiceProvider providerA = DI.services()
            .addSingleton('DITest.IUtility', 'DITest.Utility')
            .addScoped('DITest.ILogger', 'DITest.TableLogger')
            .addTransient('DITest.IAccountService', 'DITest.AccountService')
            .buildServiceProvider();

        DI.ServiceProvider providerB = (DI.ServiceProvider) providerA.getService(DI.ServiceProvider.class);

        DI.ServiceProvider providerC = ((DI.ServiceScopeFactory) providerB).createScope().getServiceProvider();

        Assert.areEqual(providerA.getService(ILogger.class), providerB.getService(ILogger.class));
        Assert.areNotEqual(providerA.getService(ILogger.class), providerC.getService(ILogger.class));
        Assert.areNotEqual(providerB.getService(ILogger.class), providerC.getService(ILogger.class));
        Assert.areEqual(providerA.getService(ILogger.class), providerB.getService('DITest.ILogger'));
        Assert.areNotEqual(providerA.getService(ILogger.class), providerC.getService('DITest.ILogger'));
        Assert.areNotEqual(providerB.getService(ILogger.class), providerC.getService('DITest.ILogger'));
    }

    @IsTest
    static void test_serviceProvider_generics1() {
        DI.ServiceProvider providerA = DI.services()
            .addSingleton('DITest.IEmailWriter', 'DITest.EmailWriter')
            .addSingleton('DITest.ITableWriter', 'DITest.TableWriter')
            .addSingleton('DITest.IAWSS3Writer', 'DITest.AWSS3Writer')
            .addSingletonFactory('DITest.ILogger', 'DITest.GenericLoggerFactory<DITest.Logger>')
            .buildServiceProvider();

        DI.ServiceProvider providerB = (DI.ServiceProvider) providerA.getService(DI.ServiceProvider.class);

        DI.ServiceProvider providerC = ((DI.ServiceScopeFactory) providerB).createScope().getServiceProvider();

        Logger emailLogger = (Logger) providerC.getService('DITest.ILogger<DITest.IEmailWriter>');
        Logger tableLogger = (Logger) providerC.getService('DITest.ILogger<DITest.ITableWriter>');
        Logger awss3Logger = (Logger) providerC.getService('DITest.ILogger<DITest.IAWSS3Writer>');

        Assert.isTrue(emailLogger.writer instanceof IEmailWriter);
        Assert.isTrue(tableLogger.writer instanceof ITableWriter);
        Assert.isTrue(awss3Logger.writer instanceof IAWSS3Writer);
        Assert.areEqual(emailLogger, providerC.getService('DITest.ILogger<DITest.IEmailWriter>'));
        Assert.areEqual(tableLogger, providerC.getService('DITest.ILogger<DITest.ITableWriter>'));
        Assert.areEqual(awss3Logger, providerC.getService('DITest.ILogger<DITest.IAWSS3Writer>'));
    }

    public interface IUtility {
    }

    public class Utility implements IUtility {
    }

    public class AnotherUtility implements IUtility {
    }

    public interface ILogger {
        void log(String message);
    }
    public interface ITableLogger {
    }
    public interface IEmailLogger {
    }
    public interface IAWSS3Logger {
    }

    public class TableLogger implements ITableLogger, ILogger {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('Table: ' + message);
        }
    }

    public class EmailLogger implements IEmailLogger, ILogger {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('Email: ' + message);
        }
    }

    public class AWSS3Logger implements IAWSS3Logger, ILogger {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('AWSS3: ' + message);
        }
    }

    public class NullLogger implements ILogger {
        public void log(String message) {
        }
    }

    public interface IAccountService {
    }

    public class AccountService implements IAccountService {
        private ILogger logger { get; set; }
        private GlobalConfiguration configuration { get; set; }

        public AccountService() {
        }

        public AccountService(ILogger logger, GlobalConfiguration confiragion) {
            this.logger = logger;
            this.configuration = configuration;
        }
    }

    // #endregion
    // ================

    // =================
    // #region Factories
    @IsTest
    static void test_factories() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.GlobalConfiguration', new GlobalConfiguration())
            .addSingleton('DITest.ILogger', 'DITest.TableLogger')
            .addSingleton('DITest.ILogger', 'DITest.EmailLogger')
            .addSingletonFactory('DITest.ILogger', 'DITest.AWSS3LoggerFactory')
            .addTransientFactory('DITest.IAccountService', 'DITest.AccountServiceFactory')
            .buildServiceProvider();

        IAccountService accountService = (IAccountService) provider.getService(IAccountService.class);
        Assert.areNotEqual(null, accountService);
        Assert.isTrue(accountService instanceof AccountService);
    }

    @IsTest
    static void test_factories_generic_services_1() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.IEmailWriter', 'DITest.EmailWriter')
            .addSingleton('DITest.ITableWriter', 'DITest.TableWriter')
            .addSingleton('DITest.IAWSS3Writer', 'DITest.AWSS3Writer')
            .addSingletonFactory('DITest.ILogger', 'DITest.GenericLoggerFactory<DITest.Logger>')
            .buildServiceProvider();

        Logger emailLogger = (Logger) provider.getService('DITest.ILogger<DITest.IEmailWriter>');
        Logger tableLogger = (Logger) provider.getService('DITest.ILogger<DITest.ITableWriter>');
        Logger awss3Logger = (Logger) provider.getService('DITest.ILogger<DITest.IAWSS3Writer>');

        Assert.isTrue(emailLogger.writer instanceof IEmailWriter);
        Assert.isTrue(tableLogger.writer instanceof ITableWriter);
        Assert.isTrue(awss3Logger.writer instanceof IAWSS3Writer);
        Assert.areEqual(emailLogger, provider.getService('DITest.ILogger<DITest.IEmailWriter>'));
        Assert.areEqual(tableLogger, provider.getService('DITest.ILogger<DITest.ITableWriter>'));
        Assert.areEqual(awss3Logger, provider.getService('DITest.ILogger<DITest.IAWSS3Writer>'));
    }

    @IsTest
    static void test_factories_generic_services_2() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.IEmailWriter', 'DITest.EmailWriter')
            .addSingleton('DITest.ITableWriter', 'DITest.TableWriter')
            .addSingleton('DITest.IAWSS3Writer', 'DITest.AWSS3Writer')
            .addSingletonFactory('DITest.ILogger', 'DITest.GenericLoggerFactory<DITest.Logger>')
            .buildServiceProvider();

        Logger emailLogger = (Logger) provider.getService('DITest.ILogger<DITest.IEmailWriter, DITest.INoService>');
        Logger tableLogger = (Logger) provider.getService('DITest.ILogger<DITest.ITableWriter, DITest.INoService>');
        Logger awss3Logger = (Logger) provider.getService('DITest.ILogger<DITest.IAWSS3Writer, DITest.INoService>');

        Assert.isTrue(emailLogger.writer instanceof IEmailWriter);
        Assert.isTrue(tableLogger.writer instanceof ITableWriter);
        Assert.isTrue(awss3Logger.writer instanceof IAWSS3Writer);
        Assert.areEqual(emailLogger, provider.getService('DITest.ILogger<DITest.IEmailWriter, DITest.INoService>'));
        Assert.areEqual(tableLogger, provider.getService('DITest.ILogger<DITest.ITableWriter, DITest.INoService>'));
        Assert.areEqual(awss3Logger, provider.getService('DITest.ILogger<DITest.IAWSS3Writer, DITest.INoService>'));
    }

    // ! Comment out before release, so no dependencies to standard SObjects such as Account and Contact!
    // @IsTest
    // static void test_factories_generic_services_sobjects() {
    //     DI.ServiceProvider provider = DI.services()
    //         .addSingletonFactory('DITest.IRepository', 'DITest.RepositoryFactory<DITest.Repository>')
    //         .buildServiceProvider();

    //     Repository repository = (Repository) provider.getService('DITest.IRepository<Account, Contact>');
    //     Assert.areEqual(2, repository.sobjectTypes.size());
    //     Assert.areEqual(Account.SObjectType, repository.sobjectTypes[0]);
    //     Assert.areEqual(Contact.SObjectType, repository.sobjectTypes[1]);
    //     throw new NoSuchElementException('Comment out before release!');
    // }

    public class GlobalConfiguration {
    }

    public class AccountServiceFactory implements DI.ServiceFactory {
        public IAccountService newInstance(DI.ServiceProvider provider, Type serviceType) {
            return new AccountService(
                (ILogger) provider.getService(ILogger.class),
                (GlobalConfiguration) provider.getService(GlobalConfiguration.class)
            );
        }
    }

    public class AWSS3LoggerFactory implements DI.ServiceFactory {
        public Object newInstance(DI.ServiceProvider serviceProvider, Type serviceType) {
            return new AWSS3Logger();
        }
    }

    public interface IWriter {
        void write(Object message);
    }

    public interface IEmailWriter {
    }

    public interface ITableWriter {
    }

    public interface IAWSS3Writer {
    }

    public class EmailWriter implements IEmailWriter, IWriter {
        public void write(Object message) {
        }
    }

    public class TableWriter implements ITableWriter, IWriter {
        public void write(Object message) {
        }
    }

    public class AWSS3Writer implements IAWSS3Writer, IWriter {
        public void write(Object message) {
        }
    }

    public class Logger implements ILogger {
        private IWriter writer { get; set; }

        public Logger() {
        }

        public Logger(IWriter writer) {
            this.writer = writer;
        }

        public void log(String message) {
            this.writer.write(message);
        }
    }

    public class GenericLoggerFactory implements DI.GenericServiceFactory {
        public ILogger newInstance(DI.ServiceProvider provider, Type servcieType, List<Type> parameterTypes) {
            return new Logger((IWriter) provider.getService(parameterTypes[0]));
        }
    }

    public interface IRepository {
    }

    public class Repository implements IRepository {
        private List<SObjectType> sobjectTypes { get; set; }

        public Repository(List<SObjectType> sobjectTypes) {
            this.sobjectTypes = sobjectTypes;
        }
    }

    public class RepositoryFactory implements DI.GenericServiceFactory {
        public IRepository newInstance(DI.ServiceProvider provider, Type servcieType, List<Type> parameterTypes) {
            List<SObjectType> sobjectTypes = new List<SObjectType>();
            for (Type parameterType : parameterTypes) {
                sobjectTypes.add(((SObject) parameterType.newInstance()).getSObjectType());
            }

            return new Repository(sobjectTypes);
        }
    }

    // #endregion
    // ================

    // ===============
    // #region Modules

    public class ModuleA extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
            services
                .addSingleton('DITest.IUtility', 'DITest.Utility')
                .addScoped('DITest.ILogger', 'DITest.TableLogger')
                .addTransient('DITest.IAccountService', 'DITest.AccountService');
        }
    }

    public class ModuleB extends DI.Module {
        protected override void import(DI.ModuleCollection modules) {
            modules.add('DITest.ModuleA');
        }

        protected override void configure(DI.ServiceCollection services) {
        }
    }

    @IsTest
    static void test_modules_lifetime() {
        DI.Module moduleA = DI.modules().get(ModuleA.class.getName());
        DI.Module moduleB = DI.modules().get(ModuleB.class.getName());

        Assert.areNotEqual(null, moduleA.getService(IUtility.class));
        Assert.areNotEqual(null, moduleB.getService(IUtility.class));
        Assert.areEqual(moduleA.getService(IUtility.class), moduleA.getService(IUtility.class));
        Assert.areEqual(moduleB.getService(IUtility.class), moduleB.getService(IUtility.class));
        Assert.areEqual(moduleA.getService(IUtility.class), moduleB.getService(IUtility.class));

        Assert.areNotEqual(null, moduleA.getService(ILogger.class));
        Assert.areNotEqual(null, moduleB.getService(ILogger.class));
        Assert.areEqual(moduleA.getService(ILogger.class), moduleA.getService(ILogger.class));
        Assert.areEqual(moduleB.getService(ILogger.class), moduleB.getService(ILogger.class));
        Assert.areNotEqual(moduleA.getService(ILogger.class), moduleB.getService(ILogger.class));

        Assert.areNotEqual(null, moduleA.getService(IAccountService.class));
        Assert.areNotEqual(null, moduleB.getService(IAccountService.class));
        Assert.areNotEqual(moduleA.getService(IAccountService.class), moduleA.getService(IAccountService.class));
        Assert.areNotEqual(moduleB.getService(IAccountService.class), moduleB.getService(IAccountService.class));
        Assert.areNotEqual(moduleA.getService(IAccountService.class), moduleB.getService(IAccountService.class));
    }

    public class ModuleC extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
            services
                .addSingleton('DITest.ILogger', 'DITest.TableLogger')
                .addScoped('DITest.ILogger', 'DITest.EmailLogger')
                .addTransient('DITest.ILogger', 'DITest.AWSS3Logger');
        }
    }

    public class ModuleD extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
            services
                .addSingleton('DITest.IEmailWriter', 'DITest.EmailWriter')
                .addSingleton('DITest.ITableWriter', 'DITest.TableWriter')
                .addSingleton('DITest.IAWSS3Writer', 'DITest.AWSS3Writer')
                .addSingletonFactory('DITest.ILogger', 'DITest.GenericLoggerFactory<DITest.Logger>');
        }
    }

    @IsTest
    static void test_modules_generic_services() {
        DI.Module moduleD = DI.modules().get(ModuleD.class.getName());

        Logger emailLogger = (Logger) moduleD.getService('DITest.ILogger<DITest.IEmailWriter>');
        Logger tableLogger = (Logger) moduleD.getService('DITest.ILogger<DITest.ITableWriter>');
        Logger awss3Logger = (Logger) moduleD.getService('DITest.ILogger<DITest.IAWSS3Writer>');

        Assert.isTrue(emailLogger.writer instanceof IEmailWriter);
        Assert.isTrue(tableLogger.writer instanceof ITableWriter);
        Assert.isTrue(awss3Logger.writer instanceof IAWSS3Writer);
        Assert.areEqual(emailLogger, moduleD.getService('DITest.ILogger<DITest.IEmailWriter>'));
        Assert.areEqual(tableLogger, moduleD.getService('DITest.ILogger<DITest.ITableWriter>'));
        Assert.areEqual(awss3Logger, moduleD.getService('DITest.ILogger<DITest.IAWSS3Writer>'));
    }

    public class Module1 extends DI.Module {
        public override void import(DI.ModuleCollection modules) {
            modules.add('DITest.Module5');
            modules.add('DITest.Module2');
        }

        protected override void configure(DI.ServiceCollection services) {
        }
    }

    public class Module2 extends DI.Module {
        public override void import(DI.ModuleCollection modules) {
            modules.add('DITest.Module4');
            modules.add('DITest.Module3');
        }

        public override void configure(DI.ServiceCollection services) {
            services.addTransient('DITest.ILogger', 'DITest.TableLogger');
        }
    }

    public class Module3 extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
            services.addTransient('DITest.ILogger', 'DITest.EmailLogger');
        }
    }

    public class Module4 extends DI.Module {
        public override void configure(DI.ServiceCollection services) {
        }
    }

    public class Module5 extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
        }
    }

    @IsTest
    static void test_modules_dependency() {
        // string names
        DI.Module module1 = DI.modules().get(Module1.class.getName());
        ILogger logger1 = (ILogger) module1.getService(ILogger.class);
        Assert.isTrue(logger1 instanceof TableLogger);

        // strong types
        DI.Module module3 = DI.modules().get(Module3.class);
        ILogger logger3 = (ILogger) module3.getService(ILogger.class);
        Assert.isTrue(logger3 instanceof EmailLogger);
    }

    @IsTest
    static void test_modules_replacement() {
        { // string names
            DI.modules().replace('DITest.LogModule', 'DITest.MockupLogModule');
            DI.Module module = DI.modules().get(LogModule.class.getName());
            Assert.isTrue(module instanceof MockupLogModule);
        }

        { // strong types
            DI.modules().replace(DITest.LogModule.class, DITest.MockupLogModule.class);
            DI.Module module = DI.modules().get(LogModule.class.getName());
            Assert.isTrue(module instanceof MockupLogModule);
        }

    }

    public class LogModule extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
            services.addSingleton('DITest.ILogger', 'DITest.TableLogger');
            services.addTransient('DITest.ILogger', 'DITest.EmailLogger');
            services.addSingletonFactory('DITest.ILogger', 'DITest.AWSS3LoggerFactory');
        }
    }

    public class MockupLogModule extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
            services.addSingleton('DITest.ILogger', 'DITest.TableLogger');
            services.addTransient('DITest.ILogger', 'DITest.EmailLogger');
            services.addSingletonFactory('DITest.ILogger', 'DITest.AWSS3LoggerFactory');
        }
    }

    // #endregion
    // ==============

    // ==================
    // #region Exceptions

    public interface INoService {
    }

    public interface INoFactory {
    }

    public interface IWrongFactory {
    }

    public class WrongFactory {
        // will give error during service resolving, because it is not factory class.
    }

    public class NullExceptionLoggerFactory implements DI.ServiceFactory {
        public ILogger newInstance(DI.ServiceProvider provider, Type servcieType) {
            Exception exp;
            try {
                Type noType = null;
                provider.getService(noType);
            } catch (DI.DIIllegalArgumentException ex) {
                exp = ex;
            }
            Assert.isTrue(exp != null);

            exp = null;
            try {
                String noName = null;
                provider.getService(noName);
            } catch (DI.DIIllegalArgumentException ex) {
                exp = ex;
            }
            Assert.isTrue(exp != null);

            throw new NullPointerException();
        }
    }

    @IsTest
    static void test_exceptions_none() {
        DI.ServiceProvider provider = DI.services().buildServiceProvider();

        INoService noService = (INoService) provider.getService(INoService.class);
        Assert.areEqual(null, noService);

        noService = (INoService) provider.getService('DITest.INoService');
        Assert.areEqual(null, noService);
    }

    @IsTest
    static void test_exceptions_hasCode() {
        GlobalConfiguration GLOBAL_CONFIGURATION = new GlobalConfiguration();
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.GlobalConfiguration', GLOBAL_CONFIGURATION)
            .addSingleton('DITest.GlobalConfiguration', GLOBAL_CONFIGURATION)
            .addSingleton('DITest.GlobalConfiguration', new GlobalConfiguration())
            .addSingleton('DITest.GlobalConfiguration', new GlobalConfiguration())
            .addSingleton('DITest.GlobalConfiguration', 'DITest.GlobalConfiguration')
            .addSingleton('DITest.GlobalConfiguration', 'DITest.GlobalConfiguration')
            .buildServiceProvider();

        Assert.areEqual(1, DI.ROOT_SERVICES.services.getDescriptors().size());
    }

    @IsTest
    static void test_exceptions() {
        DI.ServiceProvider provider = DI.services()
            .addSingleton('DITest.GlobalConfiguration', new GlobalConfiguration())
            .addSingleton('DITest.INoService', 'DITest.NoService')
            .addSingletonFactory('DITest.IWrongFactory', 'DITest.WrongFactory')
            .addSingletonFactory('DITest.ILogger', 'DITest.NullExceptionLoggerFactory')
            .addSingletonFactory('DITest.INoFactory', 'DITest.NoFactory')
            .buildServiceProvider();

        Exception exp;
        try {
            Type noType = null;
            provider.getService(noType);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);

        exp = null;
        try {
            String noName = null;
            provider.getService(noName);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);

        exp = null;
        try {
            provider.getService(INoFactory.class);
        } catch (DI.DITypeException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);

        exp = null;
        try {
            provider.getService(IWrongFactory.class);
        } catch (DI.DITypeException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);

        exp = null;
        try {
            provider.getService(ILogger.class);
        } catch (NullPointerException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);

        exp = null;
        try {
            provider.getService(INoService.class);
        } catch (DI.DITypeException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
    }

    @IsTest
    static void test_exceptions_modules() {
        Exception exp = null;
        try {
            DI.modules().get(INoService.class.getName());
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);

        exp = null;
        try {
            DI.modules().get(ExceptionModule1.class.getName());
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
    }

    public class ExceptionModule1 extends DI.Module {
        protected override void import(DI.ModuleCollection modules) {
            modules.add('DITest.INoService');
        }

        protected override void configure(DI.ServiceCollection services) {
        }
    }
    // #endregion
    // =================
}
