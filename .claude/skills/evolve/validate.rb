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
  'templates/p-4/CLAUDE.template.md'                               => ['draft-plugin/skills/prep/CLAUDE.template.md', 'draft-plugin/skills/adopt/CLAUDE.template.md'],
  'templates/p-4/claude-code-prompts.md'                           => 'draft-plugin/skills/prep/claude-code-prompts.template.md',
  'templates/p-4/doc-lint.sh'                                      => ['draft-plugin/skills/prep/doc-lint.template.sh', 'draft-plugin/skills/adopt/doc-lint.template.sh'],
}
Dir[File.join(ROOT, 'templates/p-3/project-playbook/templates/*.md')].each do |src|
  pairs[src.sub("#{ROOT}/", '')] = "draft-plugin/skills/playbook/templates/#{File.basename(src)}"
end
Dir[File.join(ROOT, 'templates/p-3/project-playbook/docs/tech-stacks-*.md')].each do |src|
  pairs[src.sub("#{ROOT}/", '')] = "draft-plugin/skills/playbook/references/#{File.basename(src)}"
end

pairs.each do |src, dsts|
  s = File.join(ROOT, src)
  next warnings << "原本が無い: #{src}" unless File.exist?(s)
  Array(dsts).each do |dst|
    d = File.join(ROOT, dst)
    next warnings << "コピーが無い: #{dst} (原本: #{src})" unless File.exist?(d)
    warnings << "内容が乖離: #{src} <-> #{dst}" if File.read(s) != File.read(d)
  end
end

# --- 4. README(原典)の templates/ 参照の実在チェック ---
readme = File.read(File.join(ROOT, 'README.md'))
readme.scan(%r{templates/[\w/.-]+}).uniq.each do |ref|
  ref = ref.sub(/\.+\z/, '')
  errors << "README.md: 参照しているテンプレートが無い: #{ref}" unless File.exist?(File.join(ROOT, ref))
end

# --- 5. スキル一覧の同期(guide の案内先と draft-plugin/README.md の表・構成ツリー) ---
guide_text    = File.exist?(File.join(PLUGIN, 'skills/guide/SKILL.md')) ? File.read(File.join(PLUGIN, 'skills/guide/SKILL.md')) : ''
plugin_readme = File.read(File.join(PLUGIN, 'README.md'))
skill_names.each do |name|
  ref = %r{/draft:#{Regexp.escape(name)}(?![a-z0-9-])}
  errors << "skills/guide/SKILL.md: /draft:#{name} への案内が無い" unless name == 'guide' || guide_text.match?(ref)
  errors << "draft-plugin/README.md: スキル表に /draft:#{name} が無い" unless plugin_readme.match?(ref)
  errors << "draft-plugin/README.md: 構成ツリーに #{name}/SKILL.md が無い" unless plugin_readme.match?(%r{(?<![\w-])#{Regexp.escape(name)}/SKILL\.md})
end

# --- 6. Agent Skills派生の同期(dist/agents/skills は draft-plugin/skills から生成する派生) ---
gen = File.join(ROOT, 'scripts', 'build-agent-skills.rb')
if File.exist?(gen)
  out = `ruby #{gen} --check 2>&1`
  unless $?.success?
    out.each_line { |l| warnings << "Agent Skills派生: #{l.strip}" unless l.strip.empty? }
  end
else
  warnings << "Agent Skills生成スクリプトが無い: scripts/build-agent-skills.rb"
end

# --- 7. 文体(README原典「テクニカルドキュメントとして書く」の決定論的な部分) ---
# 判断が要る部分(対句・誇張・翻訳調)は宣言側が持つ。ここで見るのは機械で判定できるものだけ。
# インラインコードとコードブロックは「言及」であって「使用」ではないので除く。
JP_CHAR  = /[\p{Hiragana}\p{Katakana}\p{Han}、。「」（）・]/
BOLD_MAX = 48

style_files = [
  File.join(ROOT, 'README.md'),
  File.join(PLUGIN, 'README.md'),
  *Dir[File.join(PLUGIN, 'skills', '**', '*.{md,sh,mermaid}')],
  *Dir[File.join(ROOT, 'templates', '**', '*.{md,sh,mermaid}')],
  *Dir[File.join(ROOT, '.claude', 'skills', '**', '*.md')],
].uniq.select { |f| File.file?(f) }

style_files.each do |path|
  rel      = path.sub("#{ROOT}/", '')
  in_fence = false
  File.readlines(path).each_with_index do |line, i|
    if line.strip.start_with?('```')
      in_fence = !in_fence
      next
    end
    next if in_fence

    text = line.gsub(/`[^`]*`/, '')
    n    = i + 1

    # 見出しの「タイトル — サブタイトル」と、表の「該当なし」を示す単独のem dashは対象外。
    # 狙いは和文の本文に挿入句の区切りとして入るem dashであって、これらは別の用法。
    heading = (path.end_with?('.md') && text.match?(/\A\s*\#{1,6}\s/)) ||
              (path.end_with?('.mermaid') && text.match?(/\A\s*%%/))
    scan_text = text
    if scan_text.strip.start_with?('|')
      scan_text = scan_text.split('|').map { |c| c.strip == '—' ? ' ' : c }.join('|')
    end

    idx = 0
    scan_text = '' if heading
    while (pos = scan_text.index('—', idx))
      pre  = scan_text[[0, pos - 12].max...pos].to_s
      post = scan_text[pos + 1, 12].to_s
      if pre.match?(JP_CHAR) || post.match?(JP_CHAR)
        errors << "#{rel}:#{n}: 和文中のem dash。読点・括弧・文の分割か「ラベル: 説明」に置き換える"
      end
      idx = pos + 1
    end

    text.scan(/\*\*([^*]+)\*\*/).each do |m|
      next unless m[0].length > BOLD_MAX
      errors << "#{rel}:#{n}: 太字が#{m[0].length}字(上限#{BOLD_MAX}字)。太字は段落の頭の短いラベルとUI要素にだけ使う"
    end

    # 表の1列目(ラベル列)の太字だけを見る。列の位置がすでにラベルを示しており、太字は何も指していない。
    # 2列目以降の太字は、並んだ選択肢の中から採用するものを指すなど意味を運ぶことがあるので機械で判定しない。
    if text.strip.start_with?('|')
      first = text.strip.sub(/\A\|/, '').split('|').first.to_s
      errors << "#{rel}:#{n}: 表の1列目が太字。列の位置がラベルを示すので太字は要らない" if first.include?('**')
    end
  end
end

# --- 8. 名前空間を保護した行が派生でも原文のままか ---
# 子プロセスの Claude Code 本体に渡すプロンプトは、フラット名に変換すると解決しない。
# 過去に2度、駆動スクリプトの起動プロンプトが変換されてループが何も起動しない状態で
# 出荷されかけている。印を付けた行が派生でも生き残っていることを機械で確かめる。
{
  File.join(PLUGIN, 'skills') => File.join(ROOT, 'dist', 'agents', 'skills'),
  File.join(ROOT, '.claude', 'skills') => File.join(ROOT, '.agents', 'skills'),
}.each do |src_root, dst_root|
  prefix = dst_root.include?('dist') ? 'draft-' : ''
  Dir[File.join(src_root, '**', '*')].select { |f| File.file?(f) }.sort.each do |src|
    marked = File.readlines(src).select { |l| l.include?('draft-keep-namespace') }
    next if marked.empty?

    rel   = src.sub("#{src_root}/", '')
    skill = rel.split('/').first
    dst   = File.join(dst_root, "#{prefix}#{skill}", rel.split('/')[1..].join('/'))
    unless File.exist?(dst)
      errors << "名前空間の保護: 派生が無い: #{dst.sub("#{ROOT}/", '')}"
      next
    end

    body = File.read(dst)
    marked.each do |line|
      next if body.include?(line)
      errors << "名前空間の保護: 派生で書き換えられている: #{dst.sub("#{ROOT}/", '')}: #{line.strip}"
    end
  end
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
