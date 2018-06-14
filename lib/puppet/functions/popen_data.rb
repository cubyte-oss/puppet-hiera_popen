require 'yaml'

Puppet::Functions.create_function(:popen_data) do
    dispatch :popen_data do
        param 'Struct[{commandline=>Array[String, 1], env=>Optional[Hash[String, String]], merge-env=>Optional[Boolean], pwd=>Optional[String], skip-empty=>Optional[Boolean]}]', :options
        param 'Puppet::LookupContext', :context
    end

    def popen_data(options, context)
        pwd = options.fetch('pwd', '.')
        skip_empty = options.fetch('skip-empty', false)
        env = options.fetch('env', {})
        merge_env = options.fetch('merge-env', true)
        commandline = options.fetch('commandline', [])

        raise Puppet::DataBinding::LookupError, 'Empty commandline given!' if commandline.empty?

        cmd_env = merge_env ? ENV.to_hash.merge(env) : env

        output = Dir.chdir(pwd) {
            IO.popen(cmd_env, commandline, :err=>[:child, :out]) do |io|
                io.read
            end
        }

        raise Puppet::DataBinding::LookupError, "Subprocess returned an error code: #{$?}" unless $?.success?

        begin
            data = YAML.load(output)
            if data.is_a?(Hash)
                if data.empty? and skip_empty
                    context.not_found()
                else
                    Puppet::Pops::Lookup::HieraConfig.symkeys_to_string(data)
                end
            else
                msg = _('Subprocess did not return a proper Yaml hash!')
                raise Puppet::DataBinding::LookupError, msg if Puppet[:strict] == :error && data != false
                Puppet.warning(msg)
                {}
            end
        rescue YAML::SyntaxError => ex
            # Psych errors includes the absolute path to the file, so no need to add that
            # to the message
            raise Puppet::DataBinding::LookupError, "Unable to parse the process output as Yaml: #{ex.message}"
        end
    end
end

