module LedgerWeb
  class Cell
    attr_reader :title, :value, :style
    attr_accessor :text, :align

    def initialize(title, value)
      @title = title
      @value = value
      @style = {}
      @text = value
      @align = 'left'
    end
  end

  class Report
    attr_accessor :error, :fields, :rows

    @@session = {}
    @@params = {}

    def self.session=(session)
      @@session = session
    end

    def self.session
      @@session
    end

    def self.params=(params)
      @@params = params
    end

    def self.params
      @@params
    end

    def self.from_query(query)
      params = {
        from: Report.session[:from],
        to: Report.session[:to]
      }

      @@params.each do |key, val|
        params[key.to_sym] = val
      end

      ds = LedgerWeb::Database.handle.fetch(query, params)
      report = new
      begin
        row = ds.first
        raise 'No data' if row.nil?
        ds.columns.each do |col|
          report.add_field col.to_s
        end

        ds.each do |row|
          vals = []
          ds.columns.each do |col|
            vals << Cell.new(col.to_s, row[col])
          end
          report.add_row(vals)
        end
      rescue Exception => e
        report.error = e
      end

      report
    end

    def initialize
      @fields = []
      @rows = []
    end

    def add_field(field)
      @fields << field
    end

    def add_row(row)
      if row.length != @fields.length
        raise 'row length not equal to fields length'
      end
      @rows << row
    end

    def each
      @rows.each do |row|
        yield row
      end
    end

    def pivot(column, sort_order)
      new_report = self.class.new

      bucket_column_index = 0
      fields.each_with_index do |f, i|
        if f == column
          bucket_column_index = i
          break
        else
          new_report.add_field(f)
        end
      end

      buckets = {}
      new_rows = {}

      each do |row|
        key = row[0, bucket_column_index].map(&:value)
        bucket_name = row[bucket_column_index].value
        bucket_value = row[bucket_column_index + 1].value

        buckets[bucket_name] = bucket_name unless buckets.key? bucket_name

        new_rows[key] ||= {}
        new_rows[key][bucket_name] = bucket_value
      end

      bucket_keys = buckets.keys.sort
      bucket_keys = bucket_keys.reverse if sort_order && sort_order == 'desc'

      bucket_keys.each do |bucket|
        new_report.add_field(buckets[bucket])
      end

      new_rows.each do |key, value|
        row = key.each_with_index.map { |k, i| Cell.new(new_report.fields[i], k) }
        bucket_keys.each do |b|
          row << Cell.new(b.to_s, value[b])
        end

        new_report.add_row(row)
      end

      new_report
    end
  end
end

def find_all_reports
  directories = LedgerWeb::Config.instance.get :report_directories

  reports = {}

  directories.each do |dir|
    next unless File.directory? dir
    Dir.glob(File.join(dir, '*.erb')) do |report|
      basename = File.basename(report).gsub('.erb', '')
      reports[basename] = 1
    end
  end

  reports.keys.sort.map do |report|
    name = report.split(/_/).map(&:capitalize).join(' ')
    [report, name]
  end
end
