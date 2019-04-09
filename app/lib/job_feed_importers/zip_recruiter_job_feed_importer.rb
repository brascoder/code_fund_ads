module JobFeedImporters
  class ZipRecruiterJobFeedImporter
    SOURCE       = ENUMS::JOB_SOURCES::ZIP_RECRUITER
    URL          = ENV['ZIP_RECRUITER_URL']
    BUFFER_LIMIT = 50 * 1024 * 1024
    OPTIONS = {
      headers: {
        'Content-Type' => 'text/xml',
        'Accept'       => 'text/xml',
      },
      accept_encoding: 'gzip',
    }.freeze

    def self.start(*tags)
      new(*tags).import
    end

    def initialize(*tags)
      @tags = tags.flatten
      @tags = ENUMS::KEYWORDS.values.flatten.uniq.sort if @tags.empty?
    end

    def import
      purge_jobs

      job_buffer = ''
      req = Typhoeus::Request.new(URL, OPTIONS)
      req.on_complete do |res|
        reader = Zlib::GzipReader.new(StringIO.new(res.body))
        reader.each_line do |line|
          job_buffer << line
          if job_buffer.size > BUFFER_LIMIT
            jobs = process_buffer(job_buffer)
            JobPosting.bulk_insert values: jobs if jobs.present?
            job_buffer = ''
          end
        end
      end
      req.run
    end

    private

    def purge_jobs
      JobPosting.zip_recruiter.delete_all
    end

    def process_buffer(buffer)
      jobs = []
      clean_buffer = groom_buffer(buffer)

      Nokogiri::XML::Reader(clean_buffer).each do |node|
        next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
        next unless node.name == 'job'

        fragment = Nokogiri::XML(node.outer_xml)
        break unless fragment.children.present?

        job = extract_job_params(fragment)
        jobs << job unless job.nil?
      rescue Nokogiri::XML::SyntaxError => e
        Rails.logger.error "#{self.class.name}##{__method__} failed to parse a job! #{e.inspect}"
        next
      end

      jobs
    end

    def groom_buffer(buffer)
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" \
        "<feed>\n" \
        "#{buffer.slice(buffer.index('<job>')..-1)}" \
        '</feed>'
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
      job_params[:start_date] = DateTime.parse(fragment.css('date').inner_text)
      job_params[:end_date] = Date.today
      job_params[:auto_renew] = false
      job_params[:slug] = "#{Digest::MD5.hexdigest(SOURCE)}-#{source_id}"

      job_params
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

    def parse_keywords(description)
      @tags.reduce([]) do |keywords, tag|
        tag.length > 2 && description.include?(tag) ? keywords << tag : keywords
      end
    end

    def parse_province(state)
      province = Province.find("US-#{state}")
      return [province.iso_code, 'US'] if province

      [nil, nil]
    end
  end
end
