# frozen_string_literal: true

# Ansible Playbook
# v0.2.0
#
# Copyright 2023-2026 Kyoto University of Eductaion
# Released under the MIT License
# https://opensource.org/licenses/MIT
#
# Compitable: Ruby 3.3 or higher

require_relative "runmail"

class AnsiblePlaybook < Runmail::Base
  def runmail_ansible_playbook(...)
    result = ansible_playbook(...)
    mail(result)
    result
  rescue => e
    @logger&.error e.full_message(highlight: false, order: :top)
    raise
  end

  OUT_OMIT = {
    simple: [
      /^ok: \[.*$/,
      /^skipping: \[.*$/,
      /^changed: \[.*$/,
      /^included: \/.*$/,
      /^TASK \[.*\R+(?=(TASK|PLAY) \[|PLAY RECAP)/,
      /^\R/,
    ],
    normal: [
      /^ok: \[.*$/,
      /^skipping: \[.*$/,
      /^included: \/.*$/,
      /^TASK \[.*\R+(?=(TASK|PLAY) \[|PLAY RECAP)/,
      /^\R/,
    ],
    full: [],
    json: [],
  }

  # TODO: support json format output
  #   set {"ANSIBLE_STDOUT_CALLBACK" => "json"} on first arg and parse output
  def ansible_playbook(*playbooks, check: false, limit: nil, extra_vars: [], out: :normal, **opts)
    cmd = create_cmd(*playbooks, check:, limit:, extra_vars:)
    result = run(*cmd, **opts)
    result.info_concat(playbooks.join(" "))
    result.info_concat(" (C)") if check
    result.info_concat(" [#{limit}]") if limit
    result.info_concat(" #{extra_vars.join(' ')}") unless extra_vars.empty?
    OUT_OMIT.fetch(out, []).each { |pattern| result.out_omit(pattern) }
    result
  end

  private def create_cmd(*playbooks, check: false, limit: nil, extra_vars: [])
    cmd = []
    cmd << "ansible-playbook"
    cmd << "--check" if check
    cmd << "--limit" << limit if limit
    extra_vars.each do |var|
      cmd << "--extra_vars" << var
    end
    cmd.concat(playbooks)
    cmd
  end
end
