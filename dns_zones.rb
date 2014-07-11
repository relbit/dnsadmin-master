module DnsZones
  class ZoneFile
  
    def from_json(json, z_tpl = "zone.default.erb", n_tpl = "named.default.erb")
      @data = order_records JSON.parse(json);

      template = ERB.new File.new(Config.get("tpl_path") + "/" + z_tpl).read, nil, "%"
      @z_result = template.result(binding)

      template = ERB.new File.new(Config.get("tpl_path") + "/" + n_tpl).read, nil, "%"
      @n_result = template.result(binding)

      self
    end

    def order_records(data)
      ns = []
      other = []

      data["records"].each { |record|
        if record["rtype"].upcase == "NS"
          ns << record
        else
          other << record
        end
      }

      data["records"] = (ns + other)

      data
    end

    def check_zone
      name = data["origin"]
      filename = Config.get("tmp_path") + "/" + Config.get("z_check_pref") + name

      File.open(filename, "w") { |file|
        file.puts z_result
      }

      result = system Config.get("check_command") % [name, filename]

      File.unlink filename if File.exists? filename

      result
    end

    def save(rld = false)
      raise ZoneFileCorrupted if !check_zone

      name = data["origin"]

      File.open(Config.get("zf_path") + "/" + Config.get("z_pref") + name, "w") { |file|
        file.puts z_result
      }

      File.open(Config.get("n_path") + "/" + Config.get("n_pref") + name, "w") { |file|
        file.puts n_result
      }

      File.open(Config.get("data_path") + "/" + Config.get("data_pref") + name, "w") { |file|
        file.puts data.to_json
      }

      generate_master_named

      reload if rld

      self
    end

    def reload
      puts "reloading..."
      system Config.get("command")
    end

    def delete(name)
      zonefile = Config.get("zf_path") + "/" + Config.get("z_pref") + name
      namedfile = Config.get("n_path") + "/" + Config.get("n_pref") + name
      datafile = Config.get("data_path") + "/" + Config.get("data_pref") + name

      File.unlink zonefile if File.exists? zonefile
      File.unlink namedfile if File.exists? namedfile
      File.unlink datafile if File.exists? datafile

      generate_master_named

      reload
    end

    def generate_master_named
      zones = ZoneFiles.new.list_zones

      File.open(Config.get("n_path") + '/' + Config.get("n_master"), "w") { |file|
        zones.each { |zone_name|
          file.write "include \"#{Config.get("n_path")}/#{Config.get("n_pref")}#{zone_name}\";\n"
        }
      }
    end

    def z_result
      raise NoContentLoaded if @z_result.nil?
      @z_result
    end

    def n_result
      raise NoContentLoaded if @n_result.nil?
      @n_result
    end

    def data
      raise NoContentLoaded if @data.nil?
      @data
    end
  end

  class ZoneFiles
    def list_zones
      list = []

      Dir.entries(Config.get("zf_path") + "/").each { |entry|
        list.push entry[Config.get("z_pref").length, entry.length] if entry[0, Config.get("z_pref").length] == Config.get("z_pref")
      }

      list
    end

    def list_masters(slave)
      masters = []

      list_zones.each { |zone|
        data_file = Config.get("data_path") + "/" + Config.get("data_pref") + zone
        raise DataFileMissing if !File.exists? data_file

        data = JSON.parse File.new(data_file).read

        masters.push zone if data["slaves"].include? slave
      }

      masters
    end

  end

  class NoContentLoaded < RuntimeError
  end

  class DataFileMissing < RuntimeError
  end

  class ZoneFileCorrupted < RuntimeError
  end
end