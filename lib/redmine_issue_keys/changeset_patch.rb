# frozen_string_literal: true

module RedmineIssueKeys
  module ChangesetPatch
    ISSUE_KEY_RE = /\b([A-Z][A-Z0-9]{1,15}-\d+)\b/i

    def scan_comment_for_issue_ids
      return if comments.blank?

      timelog_re = Changeset::TIMELOG_RE.source.sub(/\A\\s\+@/, '')
      ref_keywords = Setting.commit_ref_keywords.downcase.split(',').collect(&:strip)
      ref_keywords_any = ref_keywords.delete('*')
      fix_keywords = Setting.commit_update_keywords_array.pluck('keywords').flatten.compact
      kw_regexp = (ref_keywords + fix_keywords).collect {|kw| Regexp.escape(kw)}.join('|')

      referenced_issues = []
      ref_regexp = "(?:\\#\\d+|[A-Z][A-Z0-9]{1,15}-\\d+)"
      if kw_regexp.blank?
        regexp =
          %r{
            ([\s(\[,-]|^)
            (?<refs>
              #{ref_regexp}(\s+@#{timelog_re})?([\s,;&]+#{ref_regexp}(\s+@#{timelog_re})?)*
            )
            (?=[[:punct:]]|\s|<|$)
          }xi
      else
        regexp =
          %r{
            ([\s(\[,-]|^)
            (?:(?<action>#{kw_regexp})[\s:]+)?
            (?<refs>
              #{ref_regexp}(\s+@#{timelog_re})?([\s,;&]+#{ref_regexp}(\s+@#{timelog_re})?)*
            )
            (?=[[:punct:]]|\s|<|$)
          }xi
      end

      comments.scan(regexp) do |match|
        action = regexp.names.include?('action') ? Regexp.last_match[:action].to_s.downcase : nil
        refs = Regexp.last_match[:refs]
        refs_has_issue_key = refs.match?(ISSUE_KEY_RE)
        next unless action.present? || ref_keywords_any || refs_has_issue_key

        refs.scan(/(\#\d+|[A-Z][A-Z0-9]{1,15}-\d+)(\s+@#{timelog_re})?/io).each do |m|
          issue = find_referenced_issue(m[0])
          next unless issue
          next if issue_linked_to_same_commit?(issue)

          referenced_issues << issue
          next if repository.created_on && committed_on && committed_on < repository.created_on

          fix_issue(issue, action) if fix_keywords.include?(action)
          log_time(issue, m[2]) if m[2] && Setting.commit_logtime_enabled?
        end
      end

      referenced_issues.uniq!
      self.issues = referenced_issues unless referenced_issues.empty?
    end

    def find_referenced_issue(ref)
      if ref.start_with?('#')
        find_referenced_issue_by_id(ref[1..].to_i)
      else
        find_referenced_issue_by_key(ref)
      end
    end

    def find_referenced_issue_by_key(key)
      issue = Issue.find_by_issue_key(key)
      return nil if issue.nil?

      if Setting.commit_cross_project_ref?
        issue
      elsif issue.project &&
          (project == issue.project || project.is_ancestor_of?(issue.project) || project.is_descendant_of?(issue.project))
        issue
      end
    end
  end
end
