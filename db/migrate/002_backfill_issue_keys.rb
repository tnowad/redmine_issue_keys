# frozen_string_literal: true

class BackfillIssueKeys < ActiveRecord::Migration[6.1]
  class ProjectRecord < ActiveRecord::Base
    self.table_name = 'projects'
  end

  class IssueRecord < ActiveRecord::Base
    self.table_name = 'issues'
  end

  class CounterRecord < ActiveRecord::Base
    self.table_name = 'project_issue_counters'
  end

  def up
    ProjectRecord.reset_column_information
    IssueRecord.reset_column_information
    CounterRecord.reset_column_information

    used = {}

    ProjectRecord.find_each do |project|
      prefix = project.issue_key_prefix.to_s
      if prefix.blank?
        prefix = normalized_prefix(project.identifier, project.id)
      elsif !prefix.match?(/\A[A-Z][A-Z0-9]{1,15}\z/)
        prefix = normalized_prefix(prefix, project.id)
      end
      prefix = unique_prefix(prefix, project.id, used) if used[prefix]
      used[prefix] = true
      project.update_columns(issue_key_prefix: prefix)

      issues = IssueRecord.where(project_id: project.id).order(:id).to_a
      issues.each_with_index do |issue, index|
        issue_number = index + 1
        issue.update_columns(
          project_issue_number: issue_number,
          issue_key: "#{prefix}-#{issue_number}"
        )
      end

      counter = CounterRecord.find_or_initialize_by(project_id: project.id)
      counter.next_value = issues.length + 1
      counter.save!
    end
  end

  def down
    ProjectRecord.reset_column_information
    IssueRecord.reset_column_information
    CounterRecord.reset_column_information

    ProjectRecord.update_all(issue_key_prefix: nil)
    IssueRecord.update_all(project_issue_number: nil, issue_key: nil)
    CounterRecord.delete_all
  end

  private

  def normalized_prefix(identifier, project_id)
    raw = identifier.to_s.upcase.gsub(/[^A-Z0-9]/, '')
    raw = "P#{project_id}" if raw.blank?
    raw = "P#{raw}" if raw[0] =~ /\d/
    raw = "#{raw}X" if raw.length == 1
    raw[0, 16]
  end

  def unique_prefix(base, project_id, used)
    id_suffix = project_id.to_s
    candidate = "#{base[0, 16 - id_suffix.length]}#{id_suffix}"
    candidate = normalized_prefix(candidate, project_id)
    return candidate unless used[candidate]

    n = 2
    loop do
      suffix = "#{id_suffix}#{n}"
      candidate = "#{base[0, 16 - suffix.length]}#{suffix}"
      candidate = normalized_prefix(candidate, project_id)
      return candidate unless used[candidate]

      n += 1
    end
  end
end
