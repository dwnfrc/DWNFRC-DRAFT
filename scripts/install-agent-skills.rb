#!/usr/bin/env ruby
# DRAFTのスキル一式を、Agent Skills対応クライアント(Codex・Cursor等)の探索先へ導入する。
#
# 探索先は `.agents/skills/`(リポジトリ単位) と `~/.agents/skills/`(ユーザー単位)。
# 配布物は dist/agents/skills/(scripts/build-agent-skills.rb が draft-plugin/skills/ から生成する派生)で、
# 導入前に最新かを確認し、古ければ再生成してから入れる。
#
# 使い方:
#   ruby scripts/install-agent-skills.rb                  # ~/.agents/skills/ へ(全プロジェクトで有効)
#   ruby scripts/install-agent-skills.rb --project [DIR]  # DIR/.agents/skills/ へ(既定: カレントディレクトリ)
#   ruby scripts/install-agent-skills.rb --dest PATH      # 任意の探索先へ
#
#   --link       コピーせずシンボリックリンクで入れる(このリポジトリを更新すると即反映される)
#   --uninstall  入れたスキル(dist にある draft-* だけ)を取り除く
#   --dry-run    実際には書き換えず、行う操作だけを表示する
require 'fileutils'
require 'rbconfig'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

ROOT  = File.expand_path('..', __dir__)
DIST  = File.join(ROOT, 'dist', 'agents', 'skills')
BUILD = File.join(ROOT, 'scripts', 'build-agent-skills.rb')

args      = ARGV.dup
link      = !args.delete('--link').nil?
uninstall = !args.delete('--uninstall').nil?
dry_run   = !args.delete('--dry-run').nil?

def take_value(args, flag)
  i = args.index(flag)
  return nil unless i

  args.delete_at(i)
  v = args[i]
  args.delete_at(i) if v && !v.start_with?('--')
  v
end

dest_opt    = take_value(args, '--dest')
project_opt = args.include?('--project') ? (take_value(args, '--project') || Dir.pwd) : nil
unless args.empty?
  warn "不明な引数: #{args.join(' ')}"
  exit 1
end

dest =
  if dest_opt      then File.expand_path(dest_opt)
  elsif project_opt then File.join(File.expand_path(project_opt), '.agents', 'skills')
  else                  File.join(Dir.home, '.agents', 'skills')
  end

# --- 配布物を最新にする ---
unless uninstall
  unless system(RbConfig.ruby, BUILD, '--check', out: File::NULL, err: File::NULL)
    puts '配布物が古いので再生成する'
    abort '再生成に失敗した' unless system(RbConfig.ruby, BUILD)
  end
end

skills = Dir[File.join(DIST, 'draft-*')].select { |d| File.directory?(d) }.sort
abort "配布物が見つからない: #{DIST}" if skills.empty?

prefix = dry_run ? '[dry-run] ' : ''

if uninstall
  removed = skills.map { |src| File.join(dest, File.basename(src)) }.select { |p| File.exist?(p) || File.symlink?(p) }
  if removed.empty?
    puts "#{dest} に導入済みのDRAFTスキルは無い"
  else
    removed.each do |path|
      puts "#{prefix}削除: #{path}"
      FileUtils.rm_rf(path) unless dry_run
    end
    puts "#{prefix}#{removed.size} スキルを取り除いた"
  end
  exit 0
end

FileUtils.mkdir_p(dest) unless dry_run
skills.each do |src|
  target = File.join(dest, File.basename(src))
  FileUtils.rm_rf(target) if (File.exist?(target) || File.symlink?(target)) && !dry_run
  puts "#{prefix}#{link ? 'リンク' : 'コピー'}: #{target}"
  next if dry_run

  link ? File.symlink(src, target) : FileUtils.cp_r(src, target)
end

puts "#{prefix}#{skills.size} スキルを #{dest} に導入した#{link ? '(シンボリックリンク)' : ''}"
puts '呼び出し: Codex は `$draft-guide`、Cursor は `/draft-guide`(内容に応じた自動起動もあり)。迷ったら draft-guide から'
