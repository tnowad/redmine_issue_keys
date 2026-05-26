# frozen_string_literal: true

module RedmineIssueKeys
  module AutoCompletesControllerPatch
    def issues
      issues = []
      q = (params[:q] || params[:term]).to_s.strip
      status = params[:status].to_s
      issue_id = params[:issue_id].to_s

      scope = Issue.cross_project_scope(@project, params[:scope]).includes(:tracker).visible
      scope = scope.open(status == 'o') if status.present?
      scope = scope.where.not(:id => issue_id.to_i) if issue_id.present?

      if q.present?
        if q =~ /\A#?(\d+)\z/
          issues << scope.find_by(:id => $1.to_i)
        elsif q.match?(/\A[A-Z][A-Z0-9]{1,15}-\d+\z/i)
          issues << scope.find_by(:issue_key => q.upcase)
        end

        issues += scope.like(q).order(:id => :desc).limit(10).to_a
        issues.compact!
        issues.uniq!
      else
        issues += scope.order(:id => :desc).limit(10).to_a
      end

      render :json => format_issues_json(issues)
    end

    private

    def format_issues_json(issues)
      issues.map do |issue|
        display_id = issue.respond_to?(:display_id) ? issue.display_id : "##{issue.id}"

        {
          'id' => issue.id,
          'label' => "#{issue.tracker} #{display_id}: #{issue.subject.to_s.truncate(255)}",
          'value' => issue.issue_key.presence || issue.id
        }
      end
    end
  end
end
