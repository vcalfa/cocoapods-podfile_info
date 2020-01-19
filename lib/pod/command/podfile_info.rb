module Pod
  class Command
    class PodfileInfo < Command

      self.summary = 'Shows information on installed Pods.'
      self.description = <<-DESC
        Shows information on installed Pods in current Project.
        If optional `PODFILE_PATH` provided, the info will be shown for
        that specific Podfile
      DESC
      self.arguments = [
        CLAide::Argument.new('PODFILE_PATH', false)
      ]

      def self.options
        [
            ["--all", "Show information about all Pods with dependencies that are used in a project"],
            ["--md", "Output information in Markdown format"],
            ["--csv", "Output information in CSV format"],
            ["--output=filename", "Output file name"]
        ].concat(super)
      end

      def initialize(argv)
        @info_all = argv.flag?('all')
        
        @type = :text
        @type = :md if argv.flag?('md')
        @type = :csv if argv.flag?('csv')

        @style = :table 
        @style = :table if argv.flag?('csv')
        @output = argv.option('output')

        @podfile_path = argv.shift_argument
        super
      end

      def run
        use_podfile = (@podfile_path || !config.lockfile)

        if !use_podfile
          UI.puts "Using lockfile" if config.verbose?
          verify_lockfile_exists!
          lockfile = config.lockfile
          pods = lockfile.dependencies.map { |d| 
            begin
            lockfile.dependencies_to_lock_pod_named(d.name) 
            rescue 
            d
            end
          }
          pods.flatten!

          UI.puts "Using" + pods.to_s if config.verbose?
          if @info_all
            #deps = lockfile.dependencies.map{|d| d.name}
            #pods = (deps + pods).uniq
          end
        elsif @podfile_path
          podfile = Pod::Podfile.from_file(@podfile_path)
          pods = pods_from_podfile(podfile)
        else
          verify_podfile_exists!
          podfile = config.podfile
          pods = pods_from_podfile(podfile)
        end

        UI.puts "\nPods used:\n".yellow unless @info_in_md
        pods_info(pods, @style, @type)
      end

      def pods_from_podfile(podfile)
        pods = [] #podfile.dependencies
        podfile.dependencies.each {|e|  pods <<  e }
        pods.flatten!
        UI.puts "Pods depend: " + pods.to_s
        pods.collect! {|pod| (pod.is_a?(Hash)) ? pod.keys.first : pod}
      end

      def pods_info_hash(pods, keys=[:name, :version, :homepage, :summary, :license])
        pods_info = []
        @sources_manager = config.sources_manager
        pods.each do |pod|
          spec = (@sources_manager.search_by_name(pod.name).first rescue nil)
          puts pod.to_s
          if spec
            puts spec.specification.to_hash.to_s
            info = {}
            keys.each { |k| 
              val = spec.specification.send(k) 
              info[k] = val.is_a?(Array) ? val.map { |a| a.to_s } : val
            }
            info[:specific_version] = pod.specific_version.to_s
            info[:requirement] = pod.requirement.to_s
            pods_info << info
          end
        end
        pods_info
      end

      def pods_info(pods, style, type)
        pods = pods_info_hash(pods, [:name, :version, :homepage, :summary, :license, :swift_versions, :swift_version])
        report(pods, style, type)
      end

      def report(pods, style, type)
        case type
        when :md
          export_md(pods, style)
        when :csv
          export_csv(pods, style)
        else
          export_default(pods, style)
        end
      end

      def export_csv(pods, style)
        
        case style
        when :table
        else
        end

        #Header 
        UI.puts "name,version,homepage,summary,license" 
        #Body
        pods.each do |pod|
          UI.puts "#{pod[:name]},#{pod[:specific_version]},#{pod[:homepage]},\"#{pod[:summary]}\",\"#{pod[:license][:type]}\""
        end
      end

      def md_release_url(url) 
          if ! url.include? "github.com"
            return nil
          end
          releasesUrl = File.join(url, "releases") 
          githubReleases = "[Releases](#{releasesUrl})"
          githubReleases
      end

      def export_md(pods, style)
        
        header_line1 =  "| Pod | Installed ver. | Last ver. | swift_versions | swift_version | License | Releases | Summary |"
        header_line2 =  "| --- | -------------- | --------- | -------------- | ------------- | ------- | -------- | ------- |"

        File.open(@output, 'w') { |file| 
          file.write "#{header_line1}\n"
          file.write "#{header_line2}\n" 
  
          pods.each do |pod|
            githubReleases = md_release_url(pod[:homepage])
            file.write "| [#{pod[:name]}](#{pod[:homepage]}) | #{pod[:specific_version]} | #{pod[:version]} | #{pod[:swift_versions]} | #{pod[:swift_version]} | #{pod[:license][:type]} | #{githubReleases} | #{pod[:summary]}\n"            
          end
        }

        #Header 
        UI.puts header_line1
        UI.puts header_line2 

        #Body 
        pods.each do |pod|
          githubReleases = md_release_url(pod[:homepage])
          UI.puts "| [#{pod[:name]}](#{pod[:homepage]}) | #{pod[:specific_version]} | #{pod[:version]} | #{pod[:swift_versions]} | #{pod[:swift_version]} | #{pod[:license][:type]} | #{githubReleases} | #{pod[:summary]}"            
        end
      end

      def export_default(pods, style)

        #Body 
        pods.each do |pod|
          UI.puts "- #{pod[:name]} (#{pod[:specific_version]}) [#{pod[:license][:type]}]".green
          UI.puts "  #{pod[:summary]}\n\n"
        end
      end
    end
  end
end

