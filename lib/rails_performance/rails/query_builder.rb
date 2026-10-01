module RailsPerformance
  module Rails
    class QueryBuilder
      def self.compose_from(params)
        result = {}

        result[:controller] = params[:controller_eq]
        result[:action] = params[:action_eq]
        result[:format] = params[:format_eq]
        result[:status] = params[:status_eq]
        result[:user_name] = params[:user_name_eq]

        result.delete_if { |k, v| v.nil? || v.blank? }

        {q: result}
      end
    end
  end
end
