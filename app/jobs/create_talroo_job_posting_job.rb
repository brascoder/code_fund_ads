class CreateTalrooJobPostingJob < ApplicationJob
  queue_as :job_posting

  SOURCE = ENUMS::JOB_SOURCES::TALROO

  def perform(xml, tags)
    setup_tags(tags)

    fragment = Nokogiri::XML(xml)
    return unless fragment.children.present?

    job = extract_job_params(fragment)
    JobPosting.create(job) unless job.nil?
  rescue Nokogiri::XML::SyntaxError => e
    Rails.logger.error "#{self.class.name}##{__method__} failed to parse a job! #{e.inspect}"
  end

  def setup_tags(tags)
    @tags = tags.flatten
    @tags = ENUMS::KEYWORDS.values.flatten.uniq.sort if @tags.empty?
  end

  def parse_keywords(description)
    @tags.reduce([]) do |keywords, tag|
      tag.length > 2 && description.include?(tag) ? keywords << tag : keywords
    end
  end

  def parse_job_type(title)
    # Done this way so that jobs with both full-time and part-time
    # in the title will be set to full-time
    full_time = ['Full-Time', 'Full-time', 'full-time', 'Full time', 'full time']
    return ENUMS::JOB_TYPES::FULL_TIME if full_time.any? { |f| title.include?(f) }

    part_time = ['Part-Time', 'Part-time', 'part-time', 'Part time', 'part time']
    return ENUMS::JOB_TYPES::PART_TIME if part_time.any? { |p| title.include?(p) }

    ENUMS::JOB_TYPES::FULL_TIME
  end

  def parse_province(state)
    province = Province.find("US-#{state}")
    return [province.iso_code, 'US'] if province

    [nil, nil]
  end

  def extract_job_params(fragment)
    description = fragment.css('description').inner_text
    keywords = parse_keywords(description)
    return nil if keywords.empty?

    job_params = {}
    province_code, country_code = parse_province(fragment.css('state').inner_text)
    source_id = fragment.css('referencenumber').inner_text

    job_params[:status] = 'active'
    job_params[:source] = SOURCE
    job_params[:source_identifier] = source_id
    job_params[:job_type] = parse_job_type(fragment.css('title').inner_text)
    job_params[:company_name] = fragment.css('company').inner_text
    job_params[:title] = fragment.css('title').inner_text
    job_params[:description] = description
    job_params[:keywords] = keywords
    job_params[:min_annual_salary_cents] = 0
    job_params[:min_annual_salary_currency] = 'USD'
    job_params[:max_annual_salary_cents] = 0
    job_params[:max_annual_salary_currency] = 'USD'
    job_params[:remote] = false
    job_params[:remote_country_codes] = '{}'
    job_params[:city] = fragment.css('city').inner_text
    job_params[:province_code] = province_code
    job_params[:country_code] = country_code
    job_params[:url] = fragment.css('url').inner_text
    job_params[:start_date] = Chronic.parse(fragment.css('date').inner_text).to_date
    job_params[:end_date] = Date.today
    job_params[:auto_renew] = false
    job_params[:slug] = "#{Digest::MD5.hexdigest(SOURCE)}-#{source_id}"

    job_params
  end
end
