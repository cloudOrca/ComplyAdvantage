public class CreateAndScreenInvocable {
    @InvocableMethod(label='Create And Screen Customer')
    public static List<FlowOutput> createAndScreenCustomer(List<FlowInput> inputs){
        List<FlowOutput> outputs = new List<FlowOutput>();
        FlowOutput output = new FlowOutput();
        FlowInput input = inputs[0];

        Mesh_External_API__c api = Mesh_External_API__c.getOrgDefaults();
        String baseUrl = MeshExternalApi.buildBaseUrl(api);
        String token = MeshExternalApi.getToken(baseUrl + '/token', api.realm__c, api.username__c, api.password__c);

        Http http = new Http();
        HttpRequest req = MeshExternalApi.buildRequest(baseUrl + '/workflows/sync/create-and-screen?last_sync_step=ALERTING', 'POST', token);

        Customer customer = new Customer(input.customer, input.contact);
        Configuration configuration = new Configuration();
        configuration.screening_configuration_identifier = input.configurationId;
        Monitoring monitoring = new Monitoring();
        monitoring.entity_screening = new EntityScreening(input.monitoring_enabled);
        List<Product> products = new List<Product>();
        if(input.comProduct != null){
            products.add(new Product(input.comProduct));
        }
      
        String reqBody = JSON.serialize(new RequestBody(customer, configuration, monitoring, products), true);
        System.debug('reqBody reqBody' + reqBody);
        req.setBody(reqBody);
        HttpResponse res = http.send(req);
        String parsedData = res.getBody().replace('"customer-screening":', '"customer_screening":');
        String replaceCustomerCreation = parsedData.replace('"customer-creation":', '"customer_creation":');
        String replaceScoring = replaceCustomerCreation.replace('"initial-risk-scoring":', '"initial_risk_scoring":');
        System.debug('replaceScoring replaceScoring replaceScoring' + replaceScoring);
        ResponseBody responseBody = (ResponseBody)JSON.deserialize(replaceScoring, ResponseBody.class);
        System.debug('responseBody responseBody responseBody' + responseBody);
    
        if(res.getStatusCode() == 200){
            String alert_identifier = responseBody?.step_details?.alerting?.step_output?.alerts.size() > 0 && responseBody?.step_details?.alerting?.step_output?.alerts != null ? responseBody?.step_details?.alerting?.step_output?.alerts[0]?.identifier : null;
            String screening_result = responseBody?.step_details?.customer_screening?.step_output?.screening_result;
            
            if( screening_result == 'HAS_PROFILES' && alert_identifier != null ){
                List<RiskWrapper> risks = new List<RiskWrapper>();
                Boolean hasNextPage = true;
                String endpoint = '/alerts/' + alert_identifier + '/risks';

                do { 
                    Http alertHttp = new Http();
                    HttpRequest alertRequest = MeshExternalApi.buildRequest(baseUrl + endpoint, 'GET', token);
                    HttpResponse alertResponse = alertHttp.send(alertRequest);
                    System.debug('alertResponse alertResponse alertResponse' + alertResponse.getBody());

                    Map<String, Object> alertResponses = (Map<String, Object>) JSON.deserializeUntyped(alertResponse.getBody());
                    if(alertResponse.getStatusCode() == 201 || alertResponse.getStatusCode() == 200){
                        List<Object> listOfRisks = (List<Object>) alertResponses.get('risks');
                        if(listOfRisks.size() > 0){
                            for( Object riskDetail : listOfRisks ){
                                Map<String, Object> mapOfRiskDetail = (Map<String, Object>) riskDetail;
                                RiskWrapper risk = new RiskWrapper();
                                risk.identifier = (String) mapOfRiskDetail?.get('identifier');
                                risk.type = (String) mapOfRiskDetail?.get('type');
                                risk.decision = (String) mapOfRiskDetail?.get('decision');
                                risks.add(risk);
                            }
                        }

                        hasNextPage = (String) alertResponses.get('next') != null;
        
                        if(hasNextPage){
                            endpoint = (String) alertResponses.get('next');
                        }
                    } else {
                        hasNextPage = false;
                    }

                } while(hasNextPage);

                if(risks.size() > 0){
                    output.risks = risks;
                }

                output.customerId = responseBody?.step_details?.customer_creation?.step_output?.customer_identifier;
                output.riskScoreLevel = responseBody?.step_details?.initial_risk_scoring?.step_output?.overall_level;
                output.riskScoreValue = responseBody?.step_details?.initial_risk_scoring?.step_output?.overall_value;
                output.screening_result = screening_result;
                output.aml_types = responseBody?.step_details?.customer_screening?.step_output?.aml_types;
                outputs.add(output);
            }
        }

        System.debug('outputs outputs outputs' + outputs);

        return outputs;
    }

    public class FlowInput{
        @InvocableVariable(label='Screening Configuration Id' required=true)
        public String configurationId;
        
        @InvocableVariable(label='Is Monitoring Enabled' required=true)
        public Boolean monitoring_enabled;

        @InvocableVariable(label='Customer Info')
        public Account customer;

        @InvocableVariable(label='Contact Info')
        public Contact contact;

        @InvocableVariable(label='ComplyAdvantage Product')
        public ComplyAdvantage_Product__c comProduct;
    }

    public class FlowOutput {
        @InvocableVariable(label = 'Customer Id')
        public String customerId;

        @InvocableVariable(label = 'Risk Score Level')
        public String riskScoreLevel;

        @InvocableVariable(label = 'Risk Score Value')
        public Decimal riskScoreValue;

        @InvocableVariable(label = 'Screening Result')
        public String screening_result;

        @InvocableVariable(label = 'AML Types')
        public List<String> aml_types;

        @InvocableVariable(label = 'Risks')
        public List<RiskWrapper> risks;
    }

    public class RiskWrapper{
        public String identifier;
        public String type;
        public String decision;
    }

    public class ResponseBody {
        public String status;
        public StepDetails step_details;
        public List<String> steps;
        public String workflow_instance_identifier;
        public String workflow_type;
    }

    public class ResponseBodyWF {
        public String status;
        public StepDetails step_details;
        public List<String> steps;
        public String workflow_instance_identifier;
        public String workflow_type;
    }

    public class StepDetails {
        public CustomerScreening customer_screening;
        public CustomerCreation customer_creation;
        public InitialrRiskScoring initial_risk_scoring;
        public Alerting alerting;
    }

    public class Alerting {
        public StepOutput step_output;
    }

    public class InitialrRiskScoring {
        public StepOutput step_output;
    }

    public class CustomerScreening {
        public StepOutput step_output;
    }

    public class CustomerCreation {
        public StepOutput step_output;
    }

    public class StepOutput {
        public String screening_result;
        public Decimal overall_value;
        public String overall_level;
        public String customer_identifier;
        public List<String> aml_types;
        public List<Alert> alerts;
    }

    public class Alert {
        public String identifier;
    }

    public class RequestBody {
        public Customer customer {get; set;}
        public Configuration configuration {get; set;}
        public Monitoring monitoring {get; set;}
        public List<Product> product {get; set;}

        public RequestBody(Customer customer, Configuration configuration, Monitoring monitoring, List<Product> products){
            this.customer = customer;
            this.configuration = configuration;
            this.monitoring = monitoring;
            if( products.size() > 0 ){
                this.product = products;
            }
        }
    }

    public class Product {
        public BankAccount bank_account {get; set;}
        public CryptoWallet crypto_wallet {get; set;}
        public String currncy {get; set;}
        public Double monthly_payment_amount {get; set;}
        public Double monthly_received_amount {get; set;}
        public Double monthly_transaction_count {get; set;}
        public String name {get; set;}
        // public OnboardingChannel onboarding_channel {get; set;}
        public String purpose {get; set;}
        public String status {get; set;}
        
        public Product(ComplyAdvantage_Product__c product){
            if( product != null ){
                this.bank_account = new BankAccount(product.ComplyAdvantage_Bank_Account__r);
                this.crypto_wallet = new CryptoWallet(product.ComplyAdvantage_Wallet__r);
                this.monthly_payment_amount = product.Monthly_Payment_Amount__c;
                this.monthly_received_amount = product.Monthly_Received_Amount__c;
                this.monthly_transaction_count = product.Monthly_Transaction_Count__c;
                this.name = product.Name;
                this.purpose = product.Purpose__c;
                this.status = product.Status__c;
                // this.currncy = product.CurrencyIsoCode;
            }
        }
    }

    // public class OnboardingChannel {
    //     public InBranch in_branch {get; set;}
    //     public Online online {get; set;}
    // }

    public class InBranch {
        public String branch_identifier {get; set;}
    }

    public class Online {
        public String device_identifier {get; set;}
        public String device_type {get; set;}
        public String ip_address {get; set;}
        public String ip_format {get; set;}
    }

    public class CryptoWallet {
        public String managing_exchange {get; set;}
        public String wallet_identifier {get; set;}
        public CryptoWallet(ComplyAdvantage_Wallet__c wallet){
           this.managing_exchange = wallet.Managing_Exchange__c;
           this.wallet_identifier = wallet.Wallet_Identifier__c;
        }
    }

    public class BankAccount {
        public String account_number {get; set;}
        public String bic {get; set;}
        public String bban {get; set;}
        public String iban {get; set;}
        public String sort_code {get; set;}

        public BankAccount(ComplyAdvantage_Bank_Account__c bankAccount){
           this.account_number = bankAccount.Account_Number__c;
           this.bic = bankAccount.BIC__c;
           this.bban = bankAccount.BBAN__c;
           this.iban = bankAccount.IBAN__c;
           this.sort_code = bankAccount.Sort_Code__c;
        }
    }

    public class Configuration {
        // public String monitoring_configuration_identifier {get; set;}
        public String screening_configuration_identifier {get; set;}
    }

    public class Monitoring {
        public EntityScreening entity_screening {get; set;}
    }

    public class EntityScreening {
        public Boolean enabled {get; set;}
        public EntityScreening(Boolean enabled){
            this.enabled = enabled;
        }
    }
  
    public class Customer {
        public String external_identifier {get; set;}
        // public String acquisition_source {get; set;}
        // public DDDate customer_since {get; set;}
        public Company company {get; set;}
        public Person person {get; set;}

        public Customer(Account account, Contact con){
            this.external_identifier = account != null ? account.Id : con.Id;
            if(account != null){
                this.company = new Company(account);
            }
            if(con != null){
                this.person = new Person(con);
            }
        }
    }
    
    public class Company {
        public String legal_name {get; set;}
        public List<Address> address {get; set;}
        // public String company_type {get; set;}
        public String industry {get; set;}
        // public List<String> alias {get; set;}
        public DDDate incorporation_date {get; set;}
        // public String place_of_registration {get; set;}
        // public String registration_authority_identification {get; set;}
        // public String source_of_income {get; set;}
        // public String status_summary {get; set;}

        public Company(Account account){
            this.legal_name = account.Name;
            // this.company_type = account.Type;
            this.industry = account.Industry__c;
           
            if( account.Incorporation_Date__c != null ){
                this.incorporation_date = new DDDate(account.Incorporation_Date__c);
            }

            if( account.BillingAddress != null || account.ShippingAddress != null){
                this.address = new List<Address>();
                if(account.BillingAddress != null){
                    Address add = new Address();
                    add.address_line1 = account.BillingStreet;
                    add.country = account.BillingCountry;
                    add.postal_code = account.BillingPostalCode;
                    add.town_name = account.BillingCity;
                    add.type = 'BILLING_ADDRESS';
                    this.address.add(add);
                }
    
                if(account.ShippingAddress != null){
                    Address add = new Address();
                    add.address_line1 = account.ShippingStreet;
                    add.country = account.ShippingCountry;
                    add.postal_code = account.ShippingPostalCode;
                    add.town_name = account.ShippingCity;
                    add.type = 'OPERATING_ADDRESS';
                    this.address.add(add);
                }
            }
        }
    }
    
    public class Address {
        public String address_line1 {get; set;}
        public String address_line2 {get; set;}
        public String country {get; set;}
        public String country_subdivision {get; set;}
        public String postal_code {get; set;}
        public String town_name {get; set;}
        public String type {get; set;}
    }
    
    public class DDDate { 
        public Integer day {get; set;}
        public Integer month {get; set;}
        public Integer year {get; set;}
        public DDDate(Date ddate){
            this.month   = ddate.month();
            this.day     = ddate.day();
            this.year    = ddate.year();
        }
    }
    
    public class Person {
        public String last_name {get; set;}
        public List<Address> address {get; set;}
        public ContactInformation contact_information {get; set;}
        public String country_of_birth {get; set;}
        public DDDate date_of_birth {get; set;}
        public String first_name {get; set;}
        public String full_name {get; set;}
        public String gender {get; set;}
        public String industry {get; set;}
        public String middle_name {get; set;}
        public List<String> profession {get; set;}

        public Person(Contact con){
            this.last_name = con.LastName;

            if(con.MailingAddress != null){
                this.address = new List<Address>();
                Address add = new Address();
                add.address_line1 = con.MailingStreet;
                add.country = con.MailingCountry;
                add.postal_code = con.MailingPostalCode;
                add.town_name = con.MailingCity;
                add.type = 'MAILING_ADDRESS';
                this.address.add(add);
            }

            if(String.isNotEmpty(con.Email) || String.isNotEmpty(con.Fax) || String.isNotEmpty(con.Phone) || String.isNotEmpty(con.Fax) || String.isNotEmpty(con.Phone) || String.isNotEmpty(con.MobilePhone) || String.isNotEmpty(con.OtherPhone)){
                ContactInformation contact_information = new ContactInformation();
                if(String.isNotEmpty(con.Email)){
                    contact_information.email_address = new List<String>{con.Email};
                }
    
                if(String.isNotEmpty(con.Fax)){
                    contact_information.fax_number = new List<String>{con.Fax};
                }

                if(String.isNotEmpty(con.Phone) || String.isNotEmpty(con.MobilePhone) || String.isNotEmpty(con.OtherPhone)){    
                    contact_information.phone_number = new List<String>();

                    if(String.isNotEmpty(con.Phone)){
                        contact_information.phone_number.add(con.Phone);
                    }
                    if(String.isNotEmpty(con.MobilePhone)){
                        contact_information.phone_number.add(con.MobilePhone);
                    }
        
                    if(String.isNotEmpty(con.OtherPhone)){
                        contact_information.phone_number.add(con.OtherPhone);
                    }
                }
    
               this.contact_information = contact_information;
            }

            if(con.Birthdate != null){
                this.date_of_birth = new DDDate(con.Birthdate);
            }

            this.first_name = con.FirstName;
            // this.full_name = con.Name;
            this.gender = con.GenderIdentity;
            this.industry = con.Account.Industry__c;
            // this.middle_name = con.MiddleName;

            if( con.Title != null ){
                this.profession.add(con.Title);
            }

        }
    }
  
  public class ContactInformation {
    public List<String> email_address {get; set;}
    public List<String> fax_number {get; set;}
    public List<String> phone_number {get; set;}
    public List<String> url {get; set;}
  }
  
  public class NetWorth {
    public String amount {get; set;}
    // public String currencyC {get; set;}
  }
  
//   public class PersonalIdentification {
//     public DDDate date_of_expiry {get; set;}
//     public DDDate date_of_issue {get; set;}
//     public String issuing_country {get; set;}
//     // public String number {get; set;}
//     public String type {get; set;}
//   }
  
  public class ResidentialInformation {
    public String country_of_residence {get; set;}
    public String residential_status {get; set;}
  }
  
//   public class Salary {
//     public Amount amount {get; set;}
//     public String currency {get; set;}
//   }
  
  public class Amount {
    public String high {get; set;}
    public String low {get; set;}
  }
}