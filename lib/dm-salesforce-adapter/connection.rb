require 'dm-salesforce-adapter/connection/errors'

class SalesforceAdapter
  class Connection
    include Errors

    class HeaderHandler < SOAP::Header::SimpleHandler
      def initialize(tag, value)
        super(XSD::QName.new('urn:enterprise.soap.sforce.com', tag))
        @tag = tag
        @value = value
      end
      def on_simple_outbound
        @value
      end
    end

    def initialize(username, password, wsdl_path, api_dir, organization_id = nil)
      @wrapper = SoapWrapper.new("SalesforceAPI", "Soap", wsdl_path, api_dir)
      @username, @password, @organization_id = URI.unescape(username), password, organization_id
      login
    end
    attr_reader :user_id, :user_details

    def wsdl_path
      @wrapper.wsdl_path
    end

    def api_dir
      @wrapper.api_dir
    end

    def organization_id
      @user_details && @user_details.organizationId
    end

    def make_object(klass_name, values)
      obj = SalesforceAPI.const_get(klass_name).new
      values.each do |property, value|
        field = field_name_for(klass_name, property)
        if value.nil? or value == ""
          obj.fieldsToNull.push(field)
        else
          obj.send("#{field}=", value)
        end
      end
      obj
    end

    def field_name_for(klass_name, column)
      klass = SalesforceAPI.const_get(klass_name)
      fields = [column, Inflector.camelize(column.to_s), "#{column}__c".downcase]
      options = /^(#{fields.join("|")})$/i
      matches = klass.instance_methods(false).grep(options)
      if matches.any?
        matches.first
      else
        raise FieldNotFound,
            "You specified #{column} as a field, but neither #{fields.join(" or ")} exist. " \
            "Either manually specify the field name with :field, or check to make sure you have " \
            "provided a correct field name."
      end
    end

    def query(string)
      with_reconnection do
        driver.query(:queryString => string).result
      end
    rescue SOAP::FaultError => e
      raise QueryError.new(e.message, [])
    end

    def create(objects)
      call_api(:create, CreateError, "creating", objects)
    end

    def update(objects)
      call_api(:update, UpdateError, "updating", objects)
    end

    def delete(keys)
      call_api(:delete, DeleteError, "deleting", keys)
    end

    private

    def driver
      @wrapper.driver
    end

    def login
      driver
      if @organization_id
        driver.headerhandler << HeaderHandler.new("LoginScopeHeader", :organizationId => @organization_id)
      end

      begin
        result = driver.login(:username => @username, :password => @password).result
      rescue SOAP::FaultError => error
        if error.faultcode.to_s =~ /INVALID_LOGIN/
          raise LoginFailed, error.faultstring.to_s
        else
          raise error
        end
      end
      driver.endpoint_url = result.serverUrl
      driver.headerhandler << HeaderHandler.new("SessionHeader", "sessionId" => result.sessionId)
      driver.headerhandler << HeaderHandler.new("CallOptions", "client" => "client")
      @user_id = result.userId
      @user_details = result.userInfo
      driver
    end

    def call_api(method, exception_class, message, args)
      with_reconnection do
        result = driver.send(method, args)
        if result.all? {|r| r.success}
          result
        else
          # TODO: be smarter about exceptions here
          raise exception_class.new("Got some errors while #{message} Salesforce objects", result)
        end
      end
    end

    def with_reconnection(&block)
      yield
    rescue SOAP::FaultError => error
      retry_count ||= 0
      if error.faultcode.to_s =~ /INVALID_SESSION_ID/
        DataMapper.logger.debug "Got a invalid session id; reconnecting" if DataMapper.logger
        @driver = nil
        login
        retry_count += 1
        retry unless retry_count > 5
      else
        raise error
      end

      raise SessionTimeout, "The Salesforce session could not be established"
    end
  end
end
