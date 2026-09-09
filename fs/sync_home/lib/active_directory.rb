require 'logger'
require 'open3'
require 'time'

class ActiveDirectory
  def initialize(domain,
                 base: nil,
                 user_base: nil,
                 user_scope: 'subtree',
                 group_base: nil,
                 group_scope: 'subtree',
                 logger: Logger.new($stderr))
    @domain = domain
    @base = base
    @user_search = {
      base: user_base || @base,
      scope: user_scope,
    }
    @group_search = {
      base: group_base || @base,
      scope: group_scope,
    }
    @logger = logger
  end

  def users
    @users ||= dsquery_user(output: :samid)
  end

  def groups
    @groups ||= dsquery_group(output: :samid)
  end

  def get_user(username)
    user_dn = dsquery_user(filters: {samid: username}).first
    return if user_dn.nil?

    dsget_user(user_dn)
  end

  private def run_cmd(cmd, encoding: Encoding::UTF_16LE)
    o, e, s = Open3.capture3(*cmd)
    if s.exitstatus != 0 || !e.empty?
      @logger.error("Failed to run: #{cmd.join(' ')}")
      @logger.error("Error message: #{e}")
      raise 'Failed to run command'
    end
    o.encode(Encoding::UTF_8, encoding).sub(/\A\ufeff/, '')
  end

  private def dsquery_user(filters: {}, output: :dn)
    filter_opts = []
    filters.each do |name, value|
      case value
      when nil, false
        next
      when true
        filter_opts << "-#{name}"
      else
        filter_opts << "-#{name}"
        filter_opts << value
      end
    end
    cmd = [
      'dsquery', 'user',
      @user_search[:base] || 'domainroot',
      '-o', output.to_s,
      '-scope', @user_search[:scope] || 'subtree',
      *filter_opts,
      '-d', @domain,
      '-limit', '0',
      '-uc',
    ]
    result = run_cmd(cmd)
    result.each_line.map do |line|
      case line.chomp
      when /^$/
        nil
      when /^"([^"]+)"$/
        Regexp.last_match(1)
      else
        @logger.warn("Invalid user samid: #{line.chomp}")
        nil
      end
    end.compact
  end

  private def dsquery_group(filters: {}, output: :dn)
    filter_opts = []
    filters.each do |name, value|
      case value
      when nil, false
        next
      when true
        filter_opts << "-#{name}"
      when
        filter_opts << "-#{name}"
        filter_opts << value
      end
    end
    cmd = [
      'dsquery', 'group',
      @group_search[:base] || 'domainroot',
      '-o', output,
      '-scope', @group_search[:scope] || 'subtree',
      *filter_opts,
      '-d', @domain,
      '-limit', '0',
      '-uc',
    ]
    result = run_cmd(cmd)
    result.each_line.map do |line|
      case line.chomp
      when /^$/
        nil
      when /^"([^"]+)"$/
        Regexp.last_match(1)
      else
        @logger.warn("Invalid group samid: #{line.chomp}")
        nil
      end
    end.compact
  end

  private def dsget_user(dn)
    cmd = [
      'dsget', 'user',
      dn,
      *USER_DSGET_ATTRS,
      '-L',
      '-uc',
    ]
    result = run_cmd(cmd)
    user_attrs = result.each_line.map do |line|
      case line.chomp
      when /\A\s*\z/, 'dsget 成功'
        nil
      when /^(\w+): (.*)$/
        name = Regexp.last_match(1).intern
        value = Regexp.last_match(2)
        if USER_ATTR_STRS.include?(name)
          [name, value]
        elsif USER_ATTR_BOOLS.include?(name)
          case value
          when 'yes'
            [name, true]
          when 'no'
            [name, false]
          else
            @logger.warn("Invalid dsget user bool: #{line.chomp}")
            nil
          end
        elsif USER_ATTR_DATES.include?(name)
          if value == 'never'
            [name, nil]
          else
            [name, Time.strptime(value, '%Y/%m/%d')]
          end
        else
          @logger.warn("Invalid dsget user attr: #{line.chomp}")
          nil
        end
      else
        @logger.warn("Invalid dsget user line: #{line.chomp}")
        nil
      end
    end.compact.to_h
  end

  USER_ATTR_STRS = [
    :dn, # DN
    :samid, # SAM アカウント名
    :sid, # セキュリティ ID
    :upn, # ユーザー プリンシパル名
    :fn, # 名
    :mi, # ミドル ネーム
    :ln, # 姓
    :display, # 表示名
    :fnp, # 名のフリガナ
    :lnp, # 姓のフリガナ
    :displayp, # 表示名のフリガナ
    :effectivepso, # 有効なパスワード設定オブジェクト
    :empid, # 社員 ID
    :desc, # 説明
    :office, # 勤務先所在地
    :tel, # 電話番号
    :email, # 電子メール アドレス
    :hometel, # 自宅電話番号
    :pager, # ポケットベル番号
    :mobile, # 携帯電話番号
    :fax, #  FAX 番号
    :iptel, #  IP 電話番号
    :webpg, #  Web ページの URL
    :title, # 役職
    :dept, # 部署
    :company, # 会社情報
    :mgr, # 上司
    :hmdir, # ホーム ディレクトリ
    :hmdrv, # ホーム ドライブ文字
    :profile, # プロファイル パス
    :loscr, # ログオン スクリプト パス
  ]
  USER_ATTR_BOOLS = [
    :mustchpwd, # 次回ログオン時パスワード変更必要
    :canchpwd, # パスワード変更可能
    :pwdneverexpires, # パスワード有効期限切れ
    :disabled, # アカウント無効
    :reversiblepwd, # パスワード暗号化を元に戻せる状態で保存
  ]
  USER_ATTR_DATES = [
    :acctexpires, # アカウントの有効期限
  ]

  USER_ATTR_ALL = USER_ATTR_STRS + USER_ATTR_BOOLS + USER_ATTR_DATES
  USER_DSGET_ATTRS = USER_ATTR_ALL.map { |attr| "-#{attr}" }
end
