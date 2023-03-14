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
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@IsTest
public class DITest {
    public class ExceptionModule1 extends DI.Module {
        protected override void import(DI.ModuleCollection modules) {
            modules.add('DITest.INoService');
        }

        protected override void configure(DI.ServiceCollection services) {
        }
    }

    public class ExceptionModule2 extends DI.Module {
        protected override void import(DI.ModuleCollection modules) {
            modules.add('DITest.INoService', 'DITest.INoService');
        }

        protected override void configure(DI.ServiceCollection services) {
        }
    }

    public class ExceptionModule3 extends DI.Module {
        protected override void import(DI.ModuleCollection modules) {
            modules.add('DITest.LogModule', 'DITest.INoService');
        }

        protected override void configure(DI.ServiceCollection services) {
        }
    }

    @IsTest
    static void test_provider_exceptions() {
        Exception exp;
        try {
            Type noType = null;
            provider.getService(noType);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            Type noType = null;
            provider.getServices(noType);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            DI.getModule(INoService.class);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            DI.addModule(INoService.class, INoService.class);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            DI.addModule(LogModule.class, INoService.class);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            provider.getService(IWrongService.class);
        } catch (DI.DITypeException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            provider.getService(IWrongFactory.class);
        } catch (DI.DITypeException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            provider.getService(IWrongFactoryReturn.class);
        } catch (DI.DITypeException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            DI.getModule(ExceptionModule1.class);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            DI.getModule(ExceptionModule2.class);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);

        exp = null;
        try {
            DI.getModule(ExceptionModule3.class);
        } catch (DI.DIIllegalArgumentException ex) {
            exp = ex;
        }
        Assert.isTrue(exp != null);
        System.debug(exp);
    }

    @IsTest
    static void test_provider_kind_none() {
        INoService noService = (INoService) provider.getService(INoService.class);
        Assert.areEqual(null, noService);

        List<INoService> noServices = (List<INoService>) provider.getServices(INoService.class);
        Assert.areNotEqual(null, noServices);
        Assert.areEqual(0, noServices.size());
    }

    @IsTest
    static void test_provider_kind_singleton() {
        GlobalConfiguration config1 = (GlobalConfiguration) provider.getService(GlobalConfiguration.class);
        GlobalConfiguration config2 = (GlobalConfiguration) provider.getService(GlobalConfiguration.class);
        Assert.isTrue(config1 == config2);
    }

    @IsTest
    static void test_provider_kind_transient() {
        DBRepository repo1 = (DBRepository) provider.getService(DBRepository.class);
        DBRepository repo2 = (DBRepository) provider.getService(DBRepository.class);
        Assert.isTrue(repo1 != repo2);
    }

    @IsTest
    static void test_provider_kind_enumerable() {
        List<ILogger> logger = (List<ILogger>) provider.getServices(ILogger.class);

        Assert.areEqual(3, logger.size());

        Assert.isTrue(logger[0] instanceof AWSS3Logger);
        Assert.isTrue(logger[1] instanceof EmailLogger);
        Assert.isTrue(logger[2] instanceof TableLogger);

        ILogger logService = (ILogger) provider.getService(ILogger.class);
        Assert.isTrue(logService instanceof AWSS3Logger);
    }

    @IsTest
    static void test_provider_kind_enumerable_scope() {
        List<ILogger> logger1 = (List<ILogger>) provider.getServices(ILogger.class);
        List<ILogger> logger2 = (List<ILogger>) provider.getServices(ILogger.class);
        ILogger logger3 = (ILogger) provider.getService(ILogger.class); // return the last one;

        Assert.areEqual(3, logger1.size());
        Assert.areEqual(3, logger2.size());
        Assert.isTrue(logger1[0] == logger2[0]); // singleton
        Assert.isTrue(logger1[1] != logger2[1]); // transient
        Assert.isTrue(logger1[2] == logger2[2]); // singleton

        Assert.isTrue(logger1[0] == logger3); // singleton
        Assert.isTrue(logger2[0] == logger3); // singleton
        Assert.isTrue(logger1[0] instanceof AWSS3Logger);
        Assert.isTrue(logger2[0] instanceof AWSS3Logger);
        Assert.isTrue(logger3 instanceof AWSS3Logger);
    }

    @IsTest
    static void test_provider_kind_factory_polymorphism() {
        DI.ServiceProvider provider = DI.services()
            .addScopedFactory('DITest.ILogger', 'DITest.LoggerFactory')
            .addSingletonFactory('DITest.ILogger', 'DITest.LoggerFactory<DITest.TableLogger>')
            .addScopedFactory('DITest.ILogger', 'DITest.LoggerFactory<DITest.EmailLogger>')
            .addTransientFactory('DITest.ILogger', 'DITest.LoggerFactory<DITest.AWSS3Logger>')
            .buildServiceProvider();

        List<ILogger> logger = (List<ILogger>) provider.getServices(ILogger.class);

        Assert.areEqual(4, logger.size());

        Assert.isTrue(logger[0] instanceof AWSS3Logger);
        Assert.isTrue(logger[1] instanceof EmailLogger);
        Assert.isTrue(logger[2] instanceof TableLogger);
        Assert.isTrue(logger[3] instanceof NullLogger);
    }

    @IsTest
    static void test_provider_kind_factory() {
        IAccountService accountService = (IAccountService) provider.getService(IAccountService.class);
        accountService.process(new List<Account>{ new Account(), new Account(), new Account() });
    }

    @IsTest
    static void test_provider_kind_internal_serviceProvider() {
        DI.ServiceProvider serviceProvider = (DI.ServiceProvider) provider.getService(DI.ServiceProvider.class);

        IAccountService accountService = (IAccountService) serviceProvider.getService(IAccountService.class);
        accountService.process(new List<Account>{ new Account(), new Account(), new Account() });
    }

    @IsTest
    static void test_module_with_commerce_sample() {
        CartController controller = new CartController();
        Assert.areEqual('Products from CartService; Products from ProductService;', controller.getProducts());
        Assert.areEqual('CartModule Settings', controller.getSettings());

        DI.Module cartModule = DI.getModule(CartModule.class);
        ILogger logger = (ILogger) cartModule.getService(ILogger.class);
        List<ILogger> loggers = (List<ILogger>) cartModule.getServices(ILogger.class);
    }

    @IsTest
    static void test_module_kind_singlton() {
        DI.Module logModule = DI.getModule(LogModule.class);
        DI.Module cartModule = DI.getModule(CartModule.class);

        Assert.isTrue(logModule instanceof LogModule);
        Assert.isTrue(cartModule instanceof CartModule);

        ILogger logger1 = (ILogger) logModule.getService(ILogger.class);
        ILogger logger2 = (ILogger) cartModule.getService(ILogger.class);

        Assert.isTrue(logger1 instanceof AWSS3Logger);
        Assert.isTrue(logger2 instanceof AWSS3Logger);
        Assert.areEqual(logger1, logger2);
    }

    @IsTest
    static void test_module_kind_scoped() {
        DI.Module shopModule = DI.getModule(ShopModule.class);
        DI.Module cartModule = DI.getModule(CartModule.class);

        Assert.isTrue(shopModule instanceof ShopModule);
        Assert.isTrue(cartModule instanceof CartModule);

        IProductService productService1 = (IProductService) shopModule.getService(IProductService.class);
        IProductService productService2 = (IProductService) shopModule.getService(IProductService.class);
        IProductService productService3 = (IProductService) cartModule.getService(IProductService.class);
        IProductService productService4 = (IProductService) cartModule.getService(IProductService.class);

        Assert.isTrue(productService1 instanceof ProductService);
        Assert.isTrue(productService2 instanceof ProductService);
        Assert.isTrue(productService3 instanceof ProductService);
        Assert.isTrue(productService4 instanceof ProductService);
        Assert.areEqual(productService1, productService2);
        Assert.areEqual(productService3, productService4);
        Assert.areNotEqual(productService1, productService3);
    }

    @IsTest
    static void test_module_replacement() {
        DI.addModule(CartModule.class, TestCartModule.class);
        DI.Module module = DI.getModule(CartModule.class);
        Assert.isTrue(module instanceof TestCartModule);
    }

    @IsTest
    static void test_module_replacement2() {
        DI.Module module = DI.getModule(TestCartModule2.class);
        Assert.isTrue(module instanceof TestCartModule2);

        module = DI.getModule(ShopModule.class);
        Assert.isTrue(module instanceof TestShopModule);
    }

    // ============================
    // #region Genearl Test Samples

    static DI.ServiceProvider provider {
        get {
            if (provider == null) {
                provider = DI.services()
                    .addSingleton('DITest.IWrongService', 'DITest.WrongService')
                    .addSingletonFactory('DITest.IWrongFactory', 'DITest.WrongFactory')
                    .addSingletonFactory('DITest.IWrongFactoryReturn', 'DITest.AWSS3LoggerFactory<DITest.AWSS3Logger>')
                    .addSingleton('DITest.GlobalConfiguration', new GlobalConfiguration())
                    .addSingleton('DITest.GlobalConfiguration')
                    .addSingleton('DITest.ILogger', 'DITest.TableLogger')
                    .addTransient('DITest.ILogger', 'DITest.EmailLogger')
                    .addSingletonFactory('DITest.ILogger', 'DITest.AWSS3LoggerFactory')
                    .addTransient('DITest.IDBContext', new DBContext())
                    .addTransient('DITest.DBRepository')
                    .addTransientFactory('DITest.IAccountService', 'DITest.AccountServiceFactory')
                    .BuildServiceProvider();
            }
            return provider;
        }
        set;
    }

    public interface INoService {
    }

    public interface IWrongService {
    }

    public class WrongService {
        // will give error during service resolving, because it is not an implementation of IWrongService.
    }

    public interface IWrongFactory {
    }

    public interface IWrongFactoryReturn {
    }

    public class WrongFactory {
        // will give error during service resolving, because it is not factory class.
    }

    public class GlobalConfiguration {
    }

    // Logger Classes
    public interface ILogger {
        void log(String message);
    }

    public class TableLogger implements ILogger {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('Table: ' + message);
        }
    }

    public class EmailLogger implements ILogger {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('Email: ' + message);
        }
    }

    public class AWSS3Logger implements ILogger {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('AWSS3: ' + message);
        }
    }

    public class NullLogger implements ILogger {
        public void log(String message) {
        }
    }

    public class AWSS3LoggerFactory implements DI.ServiceFactory {
        public Object newInstance(Type serviceType, DI.ServiceProvider serviceProvider) {
            return new AWSS3Logger();
        }
    }

    public class LoggerFactory implements DI.ServiceFactory {
        public ILogger newInstance(Type serviceType, DI.ServiceProvider serviceProvider) {
            if (serviceType == AWSS3Logger.class) {
                return new AWSS3Logger();
            } else if (serviceType == EmailLogger.class) {
                return new EmailLogger();
            } else if (serviceType == TableLogger.class) {
                return new TableLogger();
            }
            return new NullLogger();
        }
    }

    // DB Classes
    public interface IDBContext {
        IDBContext create();
        void insertObjects(List<SObject> objects);
        IDBResult commitObjects();
    }

    public interface IDBRepository {
        IDBRepository config(IDBContext dbcontext);
        void add(SObject obj);
        void put(SObject obj);
        void del(SObject obj);
        void save();
    }

    public interface IDBResult {
    }

    public class DBContext implements IDBContext {
        public IDBContext create() {
            return new DBContext();
        }

        public void insertObjects(List<SObject> objects) {
        }

        public IDBResult commitObjects() {
            return null;
        }
    }

    public class DBRepository implements IDBRepository {
        public IDBRepository config(IDBContext dbcontext) {
            return this;
        }

        public void add(SObject obj) {
        }

        public void put(SObject obj) {
        }

        public void del(SObject obj) {
        }

        public void save() {
        }
    }

    // Account Classes
    public interface IAccountService {
        void process(List<Account> accounts);
    }

    public class AccountServiceFactory implements DI.ServiceFactory {
        public IAccountService newInstance(Type serviceType, DI.ServiceProvider provider) {
            return new AccountService(
                (List<ILogger>) provider.getServices(ILogger.class),
                (IDBContext) provider.getService(IDBContext.class),
                (DBRepository) provider.getService(DBRepository.class),
                (DBRepository) provider.getService(DBRepository.class),
                (GlobalConfiguration) provider.getService(GlobalConfiguration.class)
            );
        }
    }

    public class AccountService implements IAccountService {
        private List<ILogger> logger { get; set; }
        private IDBContext dbcontext { get; set; }
        private IDBRepository accountRepository { get; set; }
        private IDBRepository contactRepository { get; set; }
        private GlobalConfiguration configuration { get; set; }

        public AccountService(
            List<ILogger> logger,
            IDBContext dbcontext,
            IDBRepository accountRepository,
            IDBRepository contactRepository,
            GlobalConfiguration confiragion
        ) {
            this.logger = logger;
            this.dbcontext = dbcontext;
            this.accountRepository = accountRepository.config(this.dbcontext);
            this.contactRepository = contactRepository.config(this.dbcontext);
            this.configuration = configuration;

            Assert.areEqual(3, this.logger.size());
            Assert.isTrue(this.logger[0] instanceof AWSS3Logger);
            Assert.isTrue(this.logger[1] instanceof EmailLogger);
            Assert.isTrue(this.logger[2] instanceof TableLogger);
            Assert.isTrue(this.dbcontext instanceof DBContext);
            Assert.isTrue(this.accountRepository instanceof DBRepository);
            Assert.isTrue(this.contactRepository instanceof DBRepository);
        }

        public void process(List<Account> accounts) {
            for (Account account : accounts) {
                account.NumberOfEmployees = 10;
                account.BillingCity = 'Dalian';
                account.BillingCountry = 'China';
                this.accountRepository.put(account);

                Contact contact = new Contact(LastName = 'LastName', Account = account);
                this.contactRepository.add(contact);
            }
            this.accountRepository.save();
            this.contactRepository.save();

            this.dbcontext.commitObjects();
        }
    }

    // #endregion
    // ============================

    // =======================
    // #region Commerce Sample

    // 1. Abstractions
    public interface IProductService {
        String getProducts();
    }

    public interface ICartService {
        String getProducts();
        String getSettings();
    }

    // 2. Implementations
    public class ProductService implements IProductService {
        public String getProducts() {
            return 'Products from ProductService;';
        }
    }

    public class CartService implements ICartService {
        private IProductService productService { get; set; }
        private ModuleSettings settings { get; set; }
        private ILogger logger { get; set; }

        public CartService(IProductService productService, ModuleSettings settings, ILogger logger) {
            this.productService = productService;
            this.settings = settings;
            this.logger = logger;
        }

        public String getProducts() {
            return 'Products from CartService; ' + this.productService.getProducts();
        }

        public String getSettings() {
            return this.settings.setting;
        }
    }

    public class CartServiceFactory implements DI.ServiceFactory {
        public ICartService newInstance(Type serviceType, DI.ServiceProvider provider) {
            return new CartService(
                (IProductService) provider.getService(IProductService.class),
                (ModuleSettings) provider.getService(ModuleSettings.class),
                (ILogger) provider.getService(ILogger.class)
            );
        }
    }

    public class ServiceResolver {
        DI.ServiceProvider provider { get; set; }

        public ServiceResolver(DI.ServiceProvider provider) {
            this.provider = provider;
        }

        public Object getService(Type instanceType) {
            if (instanceType == CartService.class) {
                return new CartService(
                    (IProductService) provider.getService(IProductService.class),
                    (ModuleSettings) provider.getService(ModuleSettings.class),
                    (ILogger) provider.getService(ILogger.class)
                );
            }

            return null;
        }
    }

    // 3. Declarations
    public class ModuleSettings {
        public String setting { get; set; }

        public ModuleSettings(String setting) {
            this.setting = setting;
        }
    }

    public class LogModule extends DI.Module {
        protected override void configure(DI.ServiceCollection services) {
            services.addSingleton('DITest.ILogger', 'DITest.TableLogger');
            services.addTransient('DITest.ILogger', 'DITest.EmailLogger');
            services.addSingletonFactory('DITest.ILogger', 'DITest.AWSS3LoggerFactory');
        }
    }

    public virtual class ShopModule extends DI.Module {
        protected override virtual void import(DI.ModuleCollection modules) {
            modules.add('DITest.LogModule');
        }

        protected override virtual void configure(DI.ServiceCollection services) {
            services.addScoped('DITest.IProductService', 'DITest.ProductService');
            services.addSingleton('DITest.ModuleSettings', new ModuleSettings('ShopModule Settings'));
        }
    }

    public virtual class CartModule extends DI.Module {
        protected override virtual void import(DI.ModuleCollection modules) {
            modules.add('DITest.LogModule');
            modules.add('DITest.ShopModule');
        }

        protected override virtual void configure(DI.ServiceCollection services) {
            services.addTransientFactory('DITest.ICartService', 'DITest.CartServiceFactory');
            services.addSingleton('DITest.ModuleSettings', new ModuleSettings('CartModule Settings'));
        }
    }

    public class TestShopModule extends ShopModule {
        protected override void configure(DI.ServiceCollection services) {
            super.configure(services);
        }
    }

    public class TestCartModule extends CartModule {
        protected override void configure(DI.ServiceCollection services) {
            super.configure(services);
        }
    }

    public class TestCartModule2 extends CartModule {
        protected override void import(DI.ModuleCollection modules) {
            super.import(modules);
            modules.add('DITest.ShopModule', 'DITest.TestShopModule');
        }

        protected override void configure(DI.ServiceCollection services) {
            super.configure(services);
        }
    }

    // 4. Consumptions
    public class CartController {
        // Asume this is static variable
        private final DI.Module cartModule = DI.getModule(CartModule.class);
        private final ICartService cartService = (ICartService) cartModule.getService(ICartService.class);

        // Asume this is static method
        public String getProducts() {
            return cartService.getProducts();
        }

        public String getSettings() {
            return cartService.getSettings();
        }
    }

    // #endregion
    // =======================
}
