require 'rubygems' if RUBY_VERSION < "1.9"

require 'config'
require 'sinatra/base'
require 'authorization'
require 'dns_zones'
require 'erb'
require 'json'
require 'yaml'
require 'pp'

class DnsAdmin < Sinatra::Base
    
  $err_cannot_delete = 1
  $err_param_missing = 2
  $err_param_empty = 3
  $err_save_empty = 4
  $err_wrong_json = 5
  $err_unknown_zone = 6
  $err_unknown = 7
  $err_db_missing = 8
  $err_zone_corrupted = 9
  
  helpers do
    include Authorization
    
    def config
      DnsZones::Config.config
    end
  end    
    
  put '/save_zone' do        
    protected!
    content_type :json
    
    check_param "zonefile"
    reload = params.has_key?("reload") and params[:reload] == "true"
                        
    zoneFile = DnsZones::ZoneFile.new
    
    begin    
      zoneFile.from_json(params[:zonefile]).save(reload)
      ok_resp
        
    rescue JSON::ParserError
      throw(:halt, [400, resp($err_wrong_json, "Bad request - cannot parse JSON")])
    rescue DnsZones::NoContentLoaded
      throw(:halt, [400, resp($err_save_empty, "Bad request - trying to save empty file")])
    rescue DnsZones::ZoneFileCorrupted
      throw(:halt, [400, resp($err_zone_corrupted, "Bad request - zone file data is not valid")])
    rescue Exception => msg
      throw(:halt, [400, resp($err_unknown, "Bad request - Exception raised (#{msg})")])
    end
  end
  
  get '/reload_zone' do
    protected!
    content_type :json
    
    check_param "zonefile"
    name = params[:zonefile]
        
    if DnsZones::ZoneFiles.new.list_zones.include? name 
      DnsZones::ZoneFile.new.reload name
      ok_resp
    else
      throw(:halt, [400, resp($err_unknown_zone, "Bad request - zone not found")])
    end
  end
    
  get '/get_zones' do
    protected!
    content_type :json
    
    zoneFiles = DnsZones::ZoneFiles.new
    
    ok_resp "", zoneFiles.list_zones
  end
    
  get '/get_masters' do
    protected!
    content_type :json
    
    check_param "slave"
    
    begin
      ok_resp "", DnsZones::ZoneFiles.new.list_masters(params[:slave])
    rescue JSON::ParserError
      throw(:halt, [400, resp($err_wrong_json, "Bad request - corrupt db file")])
    rescue DnsZones::DataFileMissing
      throw(:halt, [400, resp($err_db_missing, "Bad request - missing db file")])
    rescue Exception => msg
      throw(:halt, [400, resp($err_unknown, "Bad request - Exception raised (#{msg})")])
    end
  end
  
  delete '/delete_zone' do
    protected!
    content_type :json
    
    check_param "zonefile"

    name = params[:zonefile]
    
    begin
      if DnsZones::ZoneFiles.new.list_zones.include? name 
        DnsZones::ZoneFile.new.delete name
        ok_resp
      else
        throw(:halt, [400, resp($err_unknown_zone, "Bad request - zone not found")])
      end
    rescue
      throw(:halt, [400, resp($err_cannot_delete, "Bad request - error while deleting file")])
    end
  end
  
  get '/' do
    erb :index
  end
  
  def check_param(name)
    if !params.has_key?(name)
      throw(:halt, [400, resp($err_param_missing, "Bad request - #{name} parameter missing")])
    end
    
    param = params[name]
    
    if param.nil? or param.empty?
      throw(:halt, [400, resp($err_param_empty, "Bad request - #{name} parameter empty")])
    end
  end
      
  def resp(err_code, msg, data = {})
    {
      :errorCode => err_code,
      :message => msg,
      :data => data
    }.to_json
  end 
  
  def ok_resp(msg = "", data = {})
    resp 0, msg, data     
  end
end

#DnsAdmin.run!