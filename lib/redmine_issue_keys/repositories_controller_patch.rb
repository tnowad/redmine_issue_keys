# frozen_string_literal: true

module RedmineIssueKeys
  module RepositoriesControllerPatch
    def add_related_issue
      @issue = issue_from_related_issue_param(params[:issue_id])
      if @issue && (!@issue.visible? || @changeset.issues.include?(@issue))
        @issue = nil
      end

      respond_to do |format|
        if @issue
          @changeset.issues << @issue
          format.api { render_api_ok }
        else
          format.api { render_api_errors "#{l(:label_issue)} #{l('activerecord.errors.messages.invalid')}" }
        end
        format.js
      end
    end

    private

    def issue_from_related_issue_param(value)
      ref = value.to_s.strip
      ref = ref.delete_prefix('#')

      if ref.match?(/\A[A-Z][A-Z0-9]{1,15}-\d+\z/i)
        issue = Issue.find_by_issue_key(ref)
        return issue if issue && @changeset.find_referenced_issue_by_id(issue.id)

        nil
      else
        @changeset.find_referenced_issue_by_id(ref)
      end
    end
  end
end
