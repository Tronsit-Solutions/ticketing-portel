module Auditable
  extend ActiveSupport::Concern

  DEFAULT_SKIPPED_ATTRIBUTES = %w[
    id created_at updated_at encrypted_password reset_password_token
    reset_password_sent_at remember_created_at sign_in_count
    current_sign_in_at last_sign_in_at current_sign_in_ip last_sign_in_ip
  ].freeze

  included do
    class_attribute :audit_skipped_attributes, default: DEFAULT_SKIPPED_ATTRIBUTES

    after_create_commit  :audit_create
    after_update_commit  :audit_update
    after_destroy_commit :audit_destroy
  end

  # Override in the including model for a friendlier "auditable_label".
  def audit_label
    respond_to?(:title) ? title : (respond_to?(:fullname) ? fullname : (respond_to?(:name) ? name : "##{id}"))
  end

  # Override to change the log's category (defaults to the model's table name).
  def audit_category
    AuditLog::SETTINGS
  end

  # Override to skip auditing under certain conditions (e.g. seed/import).
  def audit_enabled?
    true
  end

  private

  def audit_actor
    Current.user
  end

  def audit_request
    Current.request
  end

  def audit_create
    return unless audit_enabled?

    AuditLog.record!(
      actor:        audit_actor,
      action:       AuditLog::CREATE,
      category:     audit_category,
      description:  "#{audit_actor_name} created #{model_name.human.downcase} \"#{audit_label}\"",
      auditable:    self,
      changed_data: { "after" => audit_snapshot },
      request:      audit_request
    )
  end

  def audit_update
    return unless audit_enabled?

    changes = saved_changes.except(*audit_skipped_attributes)
    return if changes.blank?

    AuditLog.record!(
      actor:        audit_actor,
      action:       AuditLog::UPDATE,
      category:     audit_category,
      description:  "#{audit_actor_name} updated #{model_name.human.downcase} \"#{audit_label}\"",
      auditable:    self,
      changed_data: { "changes" => changes },
      request:      audit_request
    )
  end

  def audit_destroy
    return unless audit_enabled?

    AuditLog.record!(
      actor:        audit_actor,
      action:       AuditLog::DESTROY,
      category:     audit_category,
      description:  "#{audit_actor_name} deleted #{model_name.human.downcase} \"#{audit_label}\"",
      auditable:    nil,
      changed_data: { "before" => audit_snapshot },
      request:      audit_request
    )
  end

  def audit_actor_name
    audit_actor&.fullname.presence || "System"
  end

  def audit_snapshot
    attributes.except(*audit_skipped_attributes)
  end
end
