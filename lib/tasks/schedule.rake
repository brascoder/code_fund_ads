desc "Tasks to be executed by Heroku Scheduler"
namespace :schedule do
  desc <<~DESC
    Queues job that marks expired campaigns as archived
    NOTE: Schedule daily
  DESC
  task update_campaign_statuses: :environment do
    UpdateCampaignStatusesJob.perform_later
  end

  desc <<~DESC
    Queues job that creates transactions for daily campaign spend
    NOTE: Schedule daily
  DESC
  task create_debits_for_campaigns: :environment do
    CreateDebitsForCampaignsJob.perform_later
  end

  namespace :job_postings do
    desc <<~DESC
      Import jobs from RemoteOK.io
      NOTE: Schedule daily
    DESC
    task import_remoteok: :environment do
      tags = %w[dev javascript ruby go python c dotnet elixir]
      ImportRemoteokJobsJob.new.perform(*tags)
      puts "There are #{JobPosting.count} jobs"
    end

    desc <<~DESC
      Queues job that imports Github Jobs
      NOTE: Schedule daily
    DESC
    task import_github_jobs: :environment do
      tags = ENUMS::KEYWORDS.values.flatten.uniq.sort
      ImportGithubJobsJob.perform_later(*tags)
    end

    desc <<~DESC
      Queues job that ensures daily_summaries have been created for active campaigns and properties
      NOTE: Schedule daily
    DESC
    task daily_summaries: :environment do
      EnsureDailySummariesJob.perform_later
    end

    desc <<~DESC
      Import jobs from Talroo
      NOTE: Schedule daily
    DESC
    task import_talroo: :environment do
      tags = ENUMS::KEYWORDS.values.flatten.uniq.sort
      ImportTalrooJobsJob.new.perform(*tags)
      puts "There are #{JobPosting.count} jobs"
    end

    desc <<~DESC
      Import jobs from ZipRecruiter
      NOTE: Schedule daily
    DESC
    task import_zip_recruiter: :environment do
      tags = ENUMS::KEYWORDS.values.flatten.uniq.sort
      ImportZipRecruiterJobsJob.new.perform(*tags)
      puts "There are #{JobPosting.count} jobs"
    end
  end
end
