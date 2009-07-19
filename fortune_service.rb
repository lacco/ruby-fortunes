require 'httparty'
require 'erb'

class FortuneService
  include HTTParty
  
  base_uri "http://www.doughughes.net/WebServices/fortune/fortune.cfc"
  
  # Sets content-type to xml
  format :xml
  
  TOPICS_SOAP_TEMPLATE = ERB.new <<-EOF
    <soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:for="http://fortune.webservices">
       <soapenv:Header/>
       <soapenv:Body>
          <for:getTopics<%= operation == :list ? 'List' : 'Array'%> soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"/>
       </soapenv:Body>
    </soapenv:Envelope>
  EOF
  
  FORTUNE_SOAP_TEMPLATE = ERB.new <<-EOF
      <soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:for="http://fortune.webservices">
         <soapenv:Header/>
         <soapenv:Body>
            <for:<%=operation%> soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
               <% if pattern %>
                 <regex xsi:type="xsd:string"><%= pattern %></regex>
                 <caseSensitive xsi:type="xsd:boolean"><%= case_sensitive %></caseSensitive>
               <% end %>
               <topics xsi:type="xsd:string"><%=topics%></topics>
               <minLength xsi:type="xsd:double"><%=min_length%></minLength>
               <maxLength xsi:type="xsd:double"><%=max_length%></maxLength>
            </for:<%=operation%>>
         </soapenv:Body>
      </soapenv:Envelope>
    EOF
  
  def self.topics(opts = {})
    operation = opts[:operation] || :list
    
    response = self.post_soap(TOPICS_SOAP_TEMPLATE.result(binding), {:verbose => opts[:verbose]})

    if operation == :list 
      response["ns1:getTopicsListResponse"]["getTopicsListReturn"].split(",") 
    else 
      response["ns1:getTopicsArrayResponse"]["getTopicsArrayReturn"]["getTopicsArrayReturn"]
    end
  end

  def self.fortunes(opts = {})
    raise ArgumentError, "find_all is only allowed if pattern is given" if opts[:find_all] && opts[:pattern].nil?
  
    topics = opts[:topics] || []
    min_length = opts[:min_length] || 0
    max_length = opts[:max_length] || 0
    pattern = opts[:pattern]
    case_sensitive = opts[:case_sensitive] || false
    
    # Set find_all to false if no pattern is given
    find_all = opts[:pattern].nil? ? false : opts[:find_all]

    # Post process arguments
    topics = topics.join(",") if topics.kind_of?(Array)
    pattern = pattern.source if pattern.kind_of?(Regexp)
    
    operation = if pattern
      if find_all
        "getFortunesByPattern"
      else
        "getFortuneByPattern"
      end
    else
      "getFortune"
    end

    response = self.post_soap(FORTUNE_SOAP_TEMPLATE.result(binding), {:verbose => opts[:verbose]})["ns1:#{operation}Response"]["#{operation}Return"]
    
    find_all ? response["#{operation}Return"] : response
  end
  
  def self.post_soap(soap, opts={})
    response = self.post("", :body => soap, :headers => {"SOAPAction" => ""})

    if opts[:verbose]
      sep = "============================="
      puts sep
      puts "Request"
      puts sep
      puts soap
      
      puts sep
      puts "Response"
      puts sep
      puts response.body
      puts sep
    end

    response["soapenv:Envelope"]["soapenv:Body"]
  end
end