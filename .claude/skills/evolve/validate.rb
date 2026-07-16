#!/usr/bin/env ruby
# draft-plugin の整合性検証。evolveスキルのStep 5で必ず実行する。
# 使い方: リポジトリルートで `ruby .claude/skills/evolve/validate.rb`
require 'yaml'
require 'json'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

ROOT   = File.expand_path('../../..', __dir__)
PLUGIN = File.join(ROOT, 'draft-plugin')

errors   = []
warnings = []

skill_dirs  = Dir[File.join(PLUGIN, 'skills', '*')].select { |d| File.directory?(d) }.sort
skill_names = skill_dirs.map { |d| File.basename(d) }

# --- 1. SKILL.md のフロントマターと本文 ---
skill_dirs.each do |dir|
  name = File.basename(dir)
  path = File.join(dir, 'SKILL.md')
  rel  = "skills/#{name}/SKILL.md"

  unless File.exist?(path)
    errors << "#{rel}: SKILL.md が存在しない"
    next
  end

  text = File.read(path)
  m = text.match(/\A---\n(.*?)\n---\n/m)
  unless m
    errors << "#{rel}: フロントマターが無い"
    next
  end

  begin
    fm = YAML.safe_load(m[1])
  rescue Psych::SyntaxError => e
    errors << "#{rel}: フロントマターのYAMLパースエラー: #{e.message}"
    next
  end

  errors << "#{rel}: フロントマターのキーが規約外 #{fm.keys.sort} (name/descriptionのみ許可)" unless fm.keys.sort == %w[description name]
  errors << "#{rel}: name(#{fm['name']}) がディレクトリ名(#{name})と不一致" if fm['name'] != name
  errors << "#{rel}: description が短すぎる(20文字未満)" if fm['description'].to_s.length < 20

  body = text.sub(/\A---\n.*?\n---\n/m, '')

  # /draft:<skill> 参照の実在チェック
  body.scan(%r{/draft:([a-z0-9-]+)}).flatten.uniq.each do |ref|
    errors << "#{rel}: 存在しないスキルへの参照 /draft:#{ref}" unless skill_names.include?(ref)
  end

  # 同梱テンプレートファイル(*.template.*)参照の実在チェック
  body.scan(/[\w.-]+\.template\.(?:md|mermaid)/).uniq.each do |f|
    errors << "#{rel}: 参照している同梱ファイルが無い: #{f}" unless File.exist?(File.join(dir, f))
  end

  # templates/ references/ 配下のファイル参照の実在チェック
  body.scan(%r{(?:templates|references)/[\w.-]+\.(?:md|mermaid)}).uniq.each do |f|
    errors << "#{rel}: 参照しているファイルが無い: #{f}" unless File.exist?(File.join(dir, f))
  end
end

# --- 2. マニフェスト ---
pj = nil
begin
  pj = JSON.parse(File.read(File.join(PLUGIN, '.claude-plugin', 'plugin.json')))
  errors << "plugin.json: name(#{pj['name']}) がkebab-caseでない" unless pj['name'] =~ /\A[a-z0-9][a-z0-9-]*\z/
  errors << 'plugin.json: version が無い' unless pj['version'].to_s =~ /\A\d+\.\d+\.\d+\z/
rescue StandardError => e
  errors << "plugin.json: 読み込み失敗: #{e.message}"
end

begin
  mp = JSON.parse(File.read(File.join(ROOT, '.claude-plugin', 'marketplace.json')))
  errors << 'marketplace.json: name が無い' unless mp['name']
  errors << 'marketplace.json: owner.name が無い' unless mp.dig('owner', 'name')
  entry = (mp['plugins'] || []).find { |p| p['name'] == (pj ? pj['name'] : 'draft') }
  if entry.nil?
    errors << 'marketplace.json: draftプラグインのエントリが無い'
  elsif entry['source'] != './draft-plugin'
    errors << "marketplace.json: source(#{entry['source']}) が ./draft-plugin を指していない"
  end
rescue StandardError => e
  errors << "marketplace.json: 読み込み失敗: #{e.message}"
end

# --- 3. テンプレート原本とスキル内コピーの乖離(警告のみ) ---
pairs = {
  'templates/p-0/concept.md'                                       => 'draft-plugin/skills/concept/concept.template.md',
  'templates/p-2/design-spec.md'                                   => 'draft-plugin/skills/design-spec/design-spec.template.md',
  'templates/p-2/screen_flow.mermaid'                              => 'draft-plugin/skills/design-spec/screen_flow.template.mermaid',
  'templates/p-3/project-playbook/templates/02-02_feature-design-doc.md' => 'draft-plugin/skills/feature/feature-design-doc.template.md',
  'templates/p-4/CLAUDE.templeate.md'                              => 'draft-plugin/skills/prep/CLAUDE.template.md',
  'templates/p-4/claude-code-prompts.md'                           => 'draft-plugin/skills/prep/claude-code-prompts.template.md',
}
Dir[File.join(ROOT, 'templates/p-3/project-playbook/templates/*.md')].each do |src|
  pairs[src.sub("#{ROOT}/", '')] = "draft-plugin/skills/playbook/templates/#{File.basename(src)}"
end
Dir[File.join(ROOT, 'templates/p-3/project-playbook/docs/tech-stacks-*.md')].each do |src|
  pairs[src.sub("#{ROOT}/", '')] = "draft-plugin/skills/playbook/references/#{File.basename(src)}"
end

pairs.each do |src, dst|
  s = File.join(ROOT, src)
  d = File.join(ROOT, dst)
  next warnings << "原本が無い: #{src}" unless File.exist?(s)
  next warnings << "コピーが無い: #{dst} (原本: #{src})" unless File.exist?(d)

  warnings << "内容が乖離: #{src} <-> #{dst}" if File.read(s) != File.read(d)
end

# --- 結果 ---
puts "スキル: #{skill_names.join(', ')}"
puts
warnings.each { |w| puts "  警告: #{w}" }
errors.each   { |e| puts "  エラー: #{e}" }
puts
if errors.empty?
  puts "OK: エラー 0件, 警告 #{warnings.size}件"
else
  puts "NG: エラー #{errors.size}件, 警告 #{warnings.size}件"
  exit 1
end
