namespace :jobs do
  desc "Import jobs from RemoteOK.io"
  task import_remoteok: :environment do
    tags = %w[dev javascript ruby go python c dotnet elixir]
    ImportRemoteokJobsJob.new.perform(*tags)
    puts "There are #{JobPosting.count} jobs"
  end

  desc "Import jobs from GitHub"
  task import_github: :environment do
    tags = ENUMS::KEYWORDS.values.flatten.uniq.sort
    ImportGithubJobsJob.new.perform(*tags)
    puts "There are #{JobPosting.count} jobs"
  end

  desc "Import jobs from Talroo"
  task import_talroo: :environment do
    tags = ENUMS::KEYWORDS.values.flatten.uniq.sort
    ImportTalrooJobsJob.new.perform(*tags)
    puts "There are #{JobPosting.count} jobs"
  end
end
