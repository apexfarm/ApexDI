/**
 * BSD 3-Clause License
 *
 * Copyright (c) 2020, https://github.com/apexfarm/ApexDI
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

@IsTest
public class DITest implements DI.IServiceProvider {

    public static Object getService(Type serviceType) {
        return provider.getService(serviceType);
    }

    public static List<Object> getService(Type serviceType, List<Object> services) {
        return provider.getService(serviceType, services);
    }

    public static DI.IServiceProvider provider {
        get {
            if (provider == null) {
                provider = new DI.ServiceCollection()
                    .addSingleton(GlobalConfiguration.class)
                    .addSingleton(ILogService.class, TableLogService.class)
                    .addSingleton(ILogService.class, EmailLogService.class)
                    .addSingleton(ILogService.class, new AWSS3LogServiceFactory())
                    .addTransient(IDBContext.class, DBContext.class)
                    .addTransient(IDBRepository.class, DBRepository.class)
                    .addTransient(DBRepository.class)
                    .addTransient(IAccountService.class, new AccountServiceFactory())
                    .BuildServiceProvider();
            }
            return provider;
        }
        set;
    }

    @IsTest
    static void test_accountService() {
        IAccountService accountService = (IAccountService)getService(IAccountService.class);
        accountService.process(new List<Account> { new Account(), new Account(), new Account()});
    }

    @IsTest
    static void test_serviceCollection() {
        List<ILogService> logServices = (List<ILogService>)getService(List<ILogService>.class, new List<ILogService>());

        System.assertEquals(3, logServices.size());
        System.assert(logServices[0] instanceOf TableLogService);
        System.assert(logServices[1] instanceOf EmailLogService);
        System.assert(logServices[2] instanceOf AWSS3LogService);
    }

    @IsTest
    static void test_serviceProvider() {
        DI.IServiceProvider serviceProvider = (DI.IServiceProvider)getService(DI.IServiceProvider.class);

        IAccountService accountService = (IAccountService)serviceProvider.getService(IAccountService.class);
        accountService.process(new List<Account> { new Account(), new Account(), new Account()});
    }

    public interface ILogService {
        void log(String message);
    }

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

    public interface IDBResult {}

    public interface IAccountService {
        void process(List<Account> accounts);
    }

    public class TableLogService implements ILogService {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('Table: ' + message);
        }
    }

    public class EmailLogService implements ILogService {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('Email: ' + message);
        }
    }

    public class AWSS3LogService implements ILogService {
        List<String> messages = new List<String>();

        public void log(String message) {
            messages.add('AWSS3: ' + message);
        }
    }

    public class AWSS3LogServiceFactory implements DI.IServiceFactory {
        public Object newInstance(DI.IServiceProvider serviceProvider) {
            return new AWSS3LogService();
        }
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

    public class GlobalConfiguration {

    }

    public class AccountServiceFactory implements DI.IServiceFactory {
        public IAccountService newInstance(DI.IServiceProvider provider) {
            return new AccountService(
                (List<ILogService>)provider.getService(List<ILogService>.class, new List<ILogService>()),
                (IDBContext)provider.getService(IDBContext.class),
                (IDBRepository)provider.getService(IDBRepository.class),
                (IDBRepository)provider.getService(IDBRepository.class),
                (GlobalConfiguration)provider.getService(GlobalConfiguration.class)
            );
        }
    }

    public class AccountService implements IAccountService {
        List<ILogService> logServices { get; set; }
        IDBContext dbcontext { get; set; }
        IDBRepository accountRepository { get; set; }
        IDBRepository contactRepository { get; set; }
        GlobalConfiguration configuration { get; set; }

        AccountService(
            List<ILogService> logServices,
            IDBContext dbcontext,
            IDBRepository accountRepository,
            IDBRepository contactRepository,
            GlobalConfiguration confiragion) {

            this.logServices = logServices;
            this.dbcontext = dbcontext;
            this.accountRepository = accountRepository.config(this.dbcontext);
            this.contactRepository = contactRepository.config(this.dbcontext);
            this.configuration = configuration;

            System.assertEquals(3, this.logServices.size());
            System.assert(this.logServices[0] instanceOf TableLogService);
            System.assert(this.logServices[1] instanceOf EmailLogService);
            System.assert(this.logServices[2] instanceOf AWSS3LogService);
            System.assert(this.dbcontext instanceOf DBContext);
            System.assert(this.accountRepository instanceOf DBRepository);
            System.assert(this.contactRepository instanceOf DBRepository);
        }

        public void process(List<Account> accounts) {
            for (Account account : accounts) {
                account.NumberOfEmployees = 10;
                account.BillingCity = 'Dalian';
                account.BillingCountry = 'China';
                this.accountRepository.put(account);

                Contact contact = new Contact(
                    LastName = 'LastName',
                    Account = account
                );
                this.contactRepository.add(contact);
            }
            this.accountRepository.save();
            this.contactRepository.save();

            this.dbcontext.commitObjects();
        }
    }
}
