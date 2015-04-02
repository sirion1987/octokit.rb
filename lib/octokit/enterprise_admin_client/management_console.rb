module Octokit
  class EnterpriseAdminClient < Octokit::Client

    # Methods for the Enterprise Management Console API
    #
    # @see https://developer.github.com/v3/enterprise/management_console
    module ManagementConsole

      # Uploads a license for the first time
      #
      # @param license [String] The path to your .ghl license file.
      # @param settings [Hash] A hash configuration of the initial settings.
      #
      # @see http: //git.io/j5NT
      # @return nil
      def upload_license(license, settings = nil)
        # we fall back to raw Faraday for this because I'm suspicious
        # that Sawyer isn't handling binary POSTs correctly: http://git.io/jMir
        conn = Faraday.new(:url => @api_endpoint) do |http|
          http.headers[:user_agent] = user_agent
          http.request :multipart
          http.request :url_encoded

          http.ssl[:verify] = false

          http.use Octokit::Response::RaiseError
          http.adapter Faraday.default_adapter
        end

        params = { }
        params[:license] = Faraday::UploadIO.new(license, 'binary')
        params[:password] = @management_console_password
        params[:settings] = "#{settings.to_json}" unless settings.nil?

        @last_response = conn.post("/setup/api/start", params)
      end

      # Start a configuration process.
      #
      # @return nil
      def start_configuration
        post "/setup/api/configure", password_hash
      end

      # Upgrade an Enterprise installation
      #
      # @param license [String] The file path to your GHL file.
      # @param license [String] The file path to your GHP file.
      #
      # @return nil
      def upgrade(license=nil, package=nil)
        raise ArgumentError("You must include a license or a package file.") if license.nil? && package.nil?
        queries = license_hash
        queries[:package] = Faraday::UploadIO.new(package, "binary") unless package.nil?
        queries[:license] = Faraday::UploadIO.new(license, "binary") unless license.nil?
        post "/setup/api/upgrade", queries
      end

      # Get information about the Enterprise installation
      #
      # @return [Sawyer::Resource] The installation information
      def config_status
        get "/setup/api/configcheck", password_hash
      end
      alias :config_check :config_status

      # Get information about the Enterprise installation
      #
      # @return [Sawyer::Resource] The settings
      def settings
        get "/setup/api/settings", password_hash
      end
      alias :get_settings :settings

      # Modify the Enterprise settings
      #
      # @param settings [Hash] A hash configuration of the new settings
      #
      # @return [nil]
      def edit_settings(settings)
        queries = password_hash
        queries[:query][:settings] = "#{settings.to_json}"
        put "/setup/api/settings", queries
      end

      # Get information about the Enterprise maintenance status
      #
      # @return [Sawyer::Resource] The maintenance status
      def maintenance_status
        get "/setup/api/maintenance", password_hash
      end
      alias :get_maintenance_status :maintenance_status

      # Start (or turn off) the Enterprise maintenance mode
      #
      # @param maintenance [Hash] A hash configuration of the maintenance settings
      # @return [nil]
      def set_maintenance_status(maintenance)
        queries = password_hash
        queries[:query][:maintenance] = "#{maintenance.to_json}"
        post "/setup/api/maintenance", queries
      end
      alias :edit_maintenance_status :set_maintenance_status

      # Fetch the authorized SSH keys on the Enterprise install
      #
      # @return [Sawyer::Resource] An array of authorized SSH keys
      def authorized_keys
        get "/setup/api/settings/authorized-keys", password_hash
      end
      alias :get_authorized_keys :authorized_keys

      # Add an authorized SSH keys on the Enterprise install
      #
      # @param key Either the file path to a key, a File handler to the key, or the contents of the key itself
      # @return [Sawyer::Resource] An array of authorized SSH keys
      def add_authorized_key(key)
        queries = password_hash
        case key
        when String
          if File.exist?(key)
            key = File.open(key, "r")
            content = key.read.strip
            key.close
          else
            content = key
          end
        when File
          content = key.read.strip
          key.close
        end

        queries[:query][:authorized_key] = content
        post "/setup/api/settings/authorized-keys", queries
      end

      # Removes an authorized SSH keys from the Enterprise install
      #
      # @param key Either the file path to a key, a File handler to the key, or the contents of the key itself
      # @return [Sawyer::Resource] An array of authorized SSH keys
      def remove_authorized_key(key)
        queries = password_hash
        case key
        when String
          if File.exist?(key)
            key = File.open(key, "r")
            content = key.read.strip
            key.close
          else
            content = key
          end
        when File
          content = key.read.strip
          key.close
        end

        queries[:query][:authorized_key] = content
        delete "/setup/api/settings/authorized-keys", queries
      end
      alias :delete_authorized_key :remove_authorized_key

    end
    private

    def password_hash
      { :query => { :api_key => @management_console_password } }
    end
  end
end
