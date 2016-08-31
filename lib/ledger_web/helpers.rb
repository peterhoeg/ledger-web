require 'rack/utils'
require 'cgi'

module LedgerWeb
  module Helpers
    include Rack::Utils

    def partial(template, locals = {})
      erb(template, layout: false, locals: locals)
    end

    def table(report, _options = {})
      Table.new(report) do |t|
        t.decorate all: LedgerWeb::Decorators::NumberDecorator.new
        t.attributes[:class] = 'table table-striped table-hover table-bordered table-condensed'
        yield t if block_given?
      end.render
    end

    def query(options = {}, &block)
      q = capture(&block)
      report = Report.from_query(q)
      if options[:pivot]
        report = report.pivot(options[:pivot], options[:pivot_sort_order])
      end
      report
    end

    def expect(expected)
      not_present = []
      expected.each do |key|
        not_present << key unless params.key? key
      end

      raise "Missing params: #{not_present.join(', ')}" unless not_present.empty?
    end

    def default(key, value)
      unless Report.params.key? key
        puts "Setting #{key} to #{value}"
        Report.params[key] = value
      end
    end

    def visualization(report, _options = {}, &block)
      vis = capture(&block)
      @vis_count ||= 0
      @vis_count += 1
      @_out_buf.concat(
        partial(
          :visualization,
          report: report,
          visualization_code: vis,
          div_id: "vis_#{@vis_count}"
        )
      )
    end
  end
end
