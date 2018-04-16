namespace :nstance do
  DEFAULT_MINUTES_AGO = 30

  namespace :clean do
    desc "Remove Docker containers created before MINUTES_AGO (default #{DEFAULT_MINUTES_AGO})"
    task :docker do
      minutes_ago = (ENV["MINUTES_AGO"] || DEFAULT_MINUTES_AGO).to_i
      threshold_time = Time.now - (minutes_ago * 60)

      puts "Removing containers older than #{threshold_time}."

      removed_containers = []
      Docker::Container.all(all: true).each do |container|
        labels = container.info["Labels"]
        next unless labels && labels.key?("nstance")

        created_at = Time.at(container.info["Created"].to_i)
        if created_at < threshold_time
          container.remove(force: true)
          removed_containers << container
        end
      end

      puts "Removed #{removed_containers.size} old containers."
    end
  end
end
