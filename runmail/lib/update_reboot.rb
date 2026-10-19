# frozen_string_literal: true
# shareable_constant_value: literal

# Update & Reboot
# v0.2.0
#
# Copyright 2024-2026 Kyoto University of Eductaion
# Released under the MIT License
# https://opensource.org/licenses/MIT
#
# Compitable: Ruby 3.3 or higher

require_relative "runmail"

class UpdateReboot < Runmail::Base
  def runmail_update_reboot(...)
    result = update_reboot(...)
    mail(result)
    result
  rescue => e
    @logger&.error { e.full_message(highlight: false, order: :top) }
    raise
  end

  def update_reboot(force_reboot: false, reboot_wait: 10, **opts)
    @logger&.info { "update_reboot" }
    result = update(**opts)
    if result.success?
      if !force_reboot && !require_reboot
        result.info_concat("update only")
      elsif reboot_wait.positive?
        result << reboot(reboot_wait, **opts)
        result.info_concat("update and reboot +#{reboot_wait}")
      else
        @logger&.info { "reboot at exit" }
        at_exit { reboot(**opts) }
        result.info_concat("update and reboot now")
      end
    end
    result
  end

  def update(**)
    @logger&.info { "update" }
    case pkg_mgr
    in :dnf
      run_cat("dnf upgrade -q -y", **)
    in :apt
      run_cat("apt update -q", "apt upgrade -q -y", **)
    in :pacman
      run_cat("pacman -Syuq --noconfirm", **)
    end
  end

  def require_reboot
    @logger&.info { "require_reboot" }
    case pkg_mgr
    in :dnf
      !system("dnf needs-restarting -r >/dev/null 2>&1")
    in :apt
      FileTest.exist?("/var/run/reboot-required")
    in :pacman
      # TODO: always true, but should check libraries
      # https://unix.stackexchange.com/a/123770
      # sudo lsof +c 0 | grep 'DEL.*lib'
      true
    end
  end

  def reboot(wait = 0, **)
    time =
      if wait.positive?
        "+#{wait}"
      else
        "now"
      end
    @logger&.info { "reboot #{time}" }
    run("shutdown -r #{time}", **)
  end

  private def pkg_mgr
    @pkg_mgr ||=
      if system("which dnf >/dev/null 2>&1")
        :dnf
      elsif system("which apt >/dev/null 2>&1")
        :apt
      elsif system("which pacman >/dev/null 2>&1")
        :pacman
      else
        raise "No supported package manager was found."
      end
  end
end
