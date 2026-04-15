#!/usr/bin/env ruby
# frozen_string_literal: true

require 'cgi'
require 'csv'
require 'fileutils'
require 'open3'
require 'rexml/document'
require 'rbconfig'
require 'shellwords'
require 'tmpdir'

NS = { 'main' => 'http://schemas.openxmlformats.org/spreadsheetml/2006/main' }.freeze

def xml_text(node)
  return '' unless node

  text = REXML::XPath.match(node, './/text()').map(&:to_s).join
  CGI.unescapeHTML(text.to_s)
end

def extract_xml(xlsx_path, internal_path)
  if Gem.win_platform?
    Dir.mktmpdir('cnpa_xlsx_extract') do |dir|
      expand_xlsx_archive(xlsx_path, dir)
      extracted_path = File.join(dir, *internal_path.split('/'))
      raise "Failed to read #{internal_path} from #{xlsx_path}" unless File.exist?(extracted_path)

      return File.binread(extracted_path)
    end
  end

  escaped_xlsx = Shellwords.escape(xlsx_path)
  escaped_internal = Shellwords.escape(internal_path)
  stdout, stderr, status = Open3.capture3("unzip -p #{escaped_xlsx} #{escaped_internal}")
  raise "Failed to read #{internal_path} from #{xlsx_path}: #{stderr}" unless status.success?

  stdout
end

def expand_xlsx_archive(xlsx_path, destination)
  escaped_destination = destination.to_s.gsub("'", "''")
  Dir.mktmpdir('cnpa_xlsx_zip') do |zip_dir|
    zip_path = File.join(zip_dir, "#{File.basename(xlsx_path, '.xlsx')}.zip")
    FileUtils.cp(xlsx_path, zip_path)
    escaped_zip = zip_path.to_s.gsub("'", "''")
    command = [
      'powershell',
      '-NoProfile',
      '-Command',
      "Expand-Archive -LiteralPath '#{escaped_zip}' -DestinationPath '#{escaped_destination}' -Force"
    ]
    _stdout, stderr, status = Open3.capture3(*command)
    raise "Failed to expand #{xlsx_path}: #{stderr}" unless status.success?
  end
end

def load_shared_strings(xlsx_path)
  xml = extract_xml(xlsx_path, 'xl/sharedStrings.xml')
  doc = REXML::Document.new(xml)
  strings = []
  REXML::XPath.each(doc, '//main:si', NS) do |si|
    strings << xml_text(si)
  end
  strings
end

def col_to_index(ref)
  letters = ref[/[A-Z]+/]
  letters.chars.reduce(0) { |acc, ch| (acc * 26) + (ch.ord - 64) } - 1
end

def load_rows(xlsx_path)
  shared_strings = load_shared_strings(xlsx_path)
  xml = extract_xml(xlsx_path, 'xl/worksheets/sheet1.xml')
  doc = REXML::Document.new(xml)
  rows = []

  REXML::XPath.each(doc, '//main:sheetData/main:row', NS) do |row_node|
    row = []
    REXML::XPath.each(row_node, 'main:c', NS) do |cell|
      idx = col_to_index(cell.attributes['r'])
      value_node = REXML::XPath.first(cell, 'main:v', NS) || cell.elements['v']
      text_node = REXML::XPath.first(cell, 'main:is', NS) || cell.elements['is']
      value =
        if cell.attributes['t'] == 's'
          value_node ? shared_strings[value_node.text.to_i] : ''
        elsif cell.attributes['t'] == 'inlineStr'
          xml_text(text_node)
        else
          value_node&.text.to_s
        end
      row[idx] = value
    end
    rows << row
  end

  rows
end

STOPWORDS = %w[
  a an and at by for from in inc incorporated llc ltd media news newspaper newspapers
  of on online press publication publications the times daily weekly group company co
].freeze

def normalize_name(name)
  str = name.to_s.dup
  str = str.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
  str = str.downcase
  str = str.gsub('&', ' and ')
  str = str.gsub(/\(.*?\)/, ' ')
  str = str.gsub(/\baka\b/, ' ')
  str = str.gsub(/[^a-z0-9\s]/, ' ')
  str = str.gsub(/\bthe\b/, ' ')
  str = str.gsub(/\s+/, ' ').strip
  str
end

def significant_tokens(name)
  normalize_name(name).split.reject { |token| STOPWORDS.include?(token) }
end

def token_key(name)
  significant_tokens(name).sort.join(' ')
end

def canonical_site_url(default_website, homepage)
  raw = [homepage, default_website].find { |value| value.to_s.strip != '' }.to_s
  raw.split(',').map(&:strip).find { |item| item =~ %r{\Ahttps?://} } || raw.split(',').map(&:strip).first.to_s
end

def url_path_depth(url)
  return 99 if url.to_s.strip.empty?

  cleaned = url.to_s.sub(%r{\Ahttps?://[^/]+/?}, '')
  return 0 if cleaned.empty?

  cleaned.split('/').reject(&:empty?).length
end

def score_candidate(member_name, candidate)
  member_norm = normalize_name(member_name)
  candidate_names = [candidate[:contact_name], candidate[:child_name], candidate[:parent_org]].compact
  normalized_contact = normalize_name(candidate[:contact_name])
  normalized_child = normalize_name(candidate[:child_name])
  normalized_parent = normalize_name(candidate[:parent_org])
  norms = candidate_names.map { |name| normalize_name(name) }.reject(&:empty?).uniq
  member_tokens = significant_tokens(member_name)

  exact_contact = !normalized_contact.empty? && normalized_contact == member_norm
  exact_child = !normalized_child.empty? && normalized_child == member_norm
  exact_parent = !normalized_parent.empty? && normalized_parent == member_norm
  exact = exact_contact || exact_child || exact_parent
  key_exact = candidate_names.any? { |name| token_key(name) == token_key(member_name) && !token_key(name).empty? }

  best_overlap = 0.0
  best_contains = false
  norms.each do |norm|
    candidate_tokens = significant_tokens(norm)
    next if member_tokens.empty? || candidate_tokens.empty?

    intersection = (member_tokens & candidate_tokens).size.to_f
    union = (member_tokens | candidate_tokens).size.to_f
    overlap = intersection / union
    best_overlap = [best_overlap, overlap].max

    best_contains ||= norm.include?(member_norm) || member_norm.include?(norm)
  end

  score = 0.0
  method = 'unmatched'

  if exact
    method =
      if exact_contact
        'exact_contact'
      elsif exact_child
        'exact_child'
      else
        'exact_parent'
      end
    score = method == 'exact_parent' ? 0.9 : 1.0
  elsif key_exact
    score = 0.96
    method = 'token_exact'
  elsif best_contains && best_overlap >= 0.5
    score = 0.88 + (best_overlap * 0.05)
    method = 'contains'
  elsif best_overlap >= 0.75
    score = 0.78 + (best_overlap * 0.1)
    method = 'high_overlap'
  elsif best_overlap >= 0.5
    score = 0.55 + (best_overlap * 0.1)
    method = 'partial_overlap'
  end

  [score, method]
end

def confidence_label(score)
  return 'High' if score >= 0.95
  return 'Medium' if score >= 0.8
  return 'Low' if score >= 0.55

  'Unmatched'
end

def build_candidates(large_rows)
  header = large_rows.first
  index = header.each_with_index.to_h
  large_rows.drop(1).map do |row|
    contact_name = row[index['Contact Name']].to_s.strip
    child_name = row[index['Child Name']].to_s.strip
    parent_org = row[index['Parent Org Name']].to_s.strip
    default_website = row[index['Default Website']].to_s.strip
    homepage = row[index['Homepage']].to_s.strip
    next if [contact_name, child_name, parent_org, default_website, homepage].all?(&:empty?)

    variants = [contact_name, child_name, parent_org].reject(&:empty?)
    {
      contact_name: contact_name,
      child_name: child_name,
      parent_org: parent_org,
      default_website: default_website,
      homepage: homepage,
      site_url: canonical_site_url(default_website, homepage),
      variants: variants,
      normalized_variants: variants.map { |name| normalize_name(name) }.reject(&:empty?).uniq,
      token_keys: variants.map { |name| token_key(name) }.reject(&:empty?).uniq,
      significant_tokens: variants.flat_map { |name| significant_tokens(name) }.uniq
    }
  end.compact
end

def build_indexes(candidates)
  exact_index = Hash.new { |hash, key| hash[key] = [] }
  token_index = Hash.new { |hash, key| hash[key] = [] }
  word_index = Hash.new { |hash, key| hash[key] = [] }

  candidates.each_with_index do |candidate, idx|
    candidate[:normalized_variants].each { |norm| exact_index[norm] << idx }
    candidate[:token_keys].each { |key| token_index[key] << idx }
    candidate[:significant_tokens].each { |token| word_index[token] << idx }
  end

  { exact_index: exact_index, token_index: token_index, word_index: word_index }
end

def choose_match(member_name, candidates, indexes)
  member_norm = normalize_name(member_name)
  member_key = token_key(member_name)
  member_tokens = significant_tokens(member_name)

  candidate_ids = []
  candidate_ids.concat(indexes[:exact_index][member_norm])
  candidate_ids.concat(indexes[:token_index][member_key])
  member_tokens.each { |token| candidate_ids.concat(indexes[:word_index][token]) }
  candidate_ids = candidate_ids.uniq
  candidate_ids = candidates.each_index.to_a if candidate_ids.empty?

  matches = candidate_ids.map do |idx|
    candidate = candidates[idx]
    score, method = score_candidate(member_name, candidate)
    next if score.zero?

    candidate.merge(score: score, method: method)
  end.compact

  return nil if matches.empty?

  method_rank = {
    'exact_contact' => 0,
    'exact_child' => 1,
    'exact_parent' => 2,
    'token_exact' => 3,
    'contains' => 4,
    'high_overlap' => 5,
    'partial_overlap' => 6
  }

  matches.sort_by do |cand|
    [
      -cand[:score],
      method_rank.fetch(cand[:method], 9),
      cand[:child_name].to_s.empty? ? 0 : 1,
      url_path_depth(cand[:site_url]),
      cand[:contact_name].to_s.length,
      cand[:child_name].to_s.length
    ]
  end.first
end

def xml_escape(text)
  CGI.escapeHTML(text.to_s)
end

def column_name(index)
  name = +''
  idx = index + 1
  while idx.positive?
    idx -= 1
    name.prepend((65 + (idx % 26)).chr)
    idx /= 26
  end
  name
end

def build_sheet_xml(rows)
  max_col = rows.map(&:length).max || 0
  max_row = rows.length
  lines = []
  lines << '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
  lines << '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
  lines << "  <dimension ref=\"A1:#{column_name(max_col - 1)}#{max_row}\"/>"
  lines << '  <sheetViews><sheetView workbookViewId="0"/></sheetViews>'
  lines << '  <sheetFormatPr defaultRowHeight="15"/>'
  lines << '  <sheetData>'

  rows.each_with_index do |row, row_idx|
    lines << "    <row r=\"#{row_idx + 1}\">"
    row.each_with_index do |value, col_idx|
      next if value.nil? || value.to_s.empty?

      ref = "#{column_name(col_idx)}#{row_idx + 1}"
      style = row_idx.zero? ? ' s="1"' : ''
      lines << "      <c r=\"#{ref}\" t=\"inlineStr\"#{style}><is><t>#{xml_escape(value)}</t></is></c>"
    end
    lines << '    </row>'
  end

  lines << '  </sheetData>'
  lines << '</worksheet>'
  lines.join("\n")
end

def build_workbook_xlsx(output_path, sheet_name, rows)
  Dir.mktmpdir('cnpa_xlsx') do |dir|
    FileUtils.mkdir_p(File.join(dir, '_rels'))
    FileUtils.mkdir_p(File.join(dir, 'docProps'))
    FileUtils.mkdir_p(File.join(dir, 'xl', '_rels'))
    FileUtils.mkdir_p(File.join(dir, 'xl', 'worksheets'))

    File.write(File.join(dir, '[Content_Types].xml'), <<~XML)
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
        <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
      </Types>
    XML

    File.write(File.join(dir, '_rels', '.rels'), <<~XML)
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
        <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
      </Relationships>
    XML

    File.write(File.join(dir, 'docProps', 'core.xml'), <<~XML)
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <dc:creator>Codex</dc:creator>
        <cp:lastModifiedBy>Codex</cp:lastModifiedBy>
        <dcterms:created xsi:type="dcterms:W3CDTF">#{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')}</dcterms:created>
        <dcterms:modified xsi:type="dcterms:W3CDTF">#{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')}</dcterms:modified>
      </cp:coreProperties>
    XML

    File.write(File.join(dir, 'docProps', 'app.xml'), <<~XML)
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
        <Application>Codex</Application>
      </Properties>
    XML

    File.write(File.join(dir, 'xl', 'workbook.xml'), <<~XML)
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
          <sheet name="#{xml_escape(sheet_name)}" sheetId="1" r:id="rId1"/>
        </sheets>
      </workbook>
    XML

    File.write(File.join(dir, 'xl', '_rels', 'workbook.xml.rels'), <<~XML)
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
      </Relationships>
    XML

    File.write(File.join(dir, 'xl', 'styles.xml'), <<~XML)
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <fonts count="2">
          <font><sz val="11"/><name val="Calibri"/></font>
          <font><b/><sz val="11"/><name val="Calibri"/></font>
        </fonts>
        <fills count="2">
          <fill><patternFill patternType="none"/></fill>
          <fill><patternFill patternType="gray125"/></fill>
        </fills>
        <borders count="1">
          <border><left/><right/><top/><bottom/><diagonal/></border>
        </borders>
        <cellStyleXfs count="1">
          <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
        </cellStyleXfs>
        <cellXfs count="2">
          <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
          <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
        </cellXfs>
      </styleSheet>
    XML

    File.write(File.join(dir, 'xl', 'worksheets', 'sheet1.xml'), build_sheet_xml(rows))

    package_xlsx_archive(dir, output_path)
  end
end

def package_xlsx_archive(source_dir, output_path)
  if Gem.win_platform?
    File.delete(output_path) if File.exist?(output_path)
    Dir.mktmpdir('cnpa_xlsx_zip') do |zip_dir|
      zip_path = File.join(zip_dir, "#{File.basename(output_path, '.xlsx')}.zip")
      escaped_source = source_dir.to_s.gsub("'", "''")
      escaped_zip = zip_path.to_s.gsub("'", "''")
      command = [
        'powershell',
        '-NoProfile',
        '-Command',
        "Compress-Archive -Path (Join-Path '#{escaped_source}' '*') -DestinationPath '#{escaped_zip}' -Force"
      ]
      _stdout, stderr, status = Open3.capture3(*command)
      raise "Failed to create #{output_path}: #{stderr}" unless status.success?

      FileUtils.mv(zip_path, output_path)
    end
    return
  end

  Dir.chdir(source_dir) do
    system('zip', '-qr', output_path, '.', exception: true)
  end
end

if __FILE__ == $PROGRAM_NAME
  member_rows = load_rows('CNPA member spreadsheet.xlsx')
  large_rows = load_rows('CNPA large spreadsheet.xlsx')

  member_header = member_rows.first
  member_idx = member_header.each_with_index.to_h
  candidates = build_candidates(large_rows)
  indexes = build_indexes(candidates)

  output_rows = [[
    'Member Publication Name',
    'Matched Publication Name',
    'Parent Org',
    'Homepage URL',
    'Match Confidence',
    'Match Method',
    'Notes',
    'Opinion Section URL',
    'RSS Opinion feed Y/N',
    'RSS feed URL',
    'Non-RSS Opinion Page Y/N',
    'Monitoring Method'
  ]]

member_rows.drop(1).each do |row|
  member_name = row[member_idx['Contact Name']].to_s.strip
  next if member_name.empty?
  next if member_name == 'Count\Average\Totals'
  next if member_name.start_with?('Generated ')

  match = choose_match(member_name, candidates, indexes)

    if match
      matched_name =
        if %w[exact_contact exact_parent].include?(match[:method])
          match[:contact_name]
        elsif match[:child_name].to_s.empty?
          match[:contact_name]
        else
          match[:child_name]
        end
      notes = []
      notes << 'Review manually' unless confidence_label(match[:score]) == 'High'
      notes << 'No homepage URL found in large sheet' if match[:site_url].to_s.empty?
      if match[:method] == 'exact_parent'
        notes << "Matched via parent organization: #{match[:parent_org]}"
      elsif match[:method] == 'exact_contact' && !match[:child_name].to_s.empty?
        notes << 'Large sheet record is an organization/group row with attached child publications'
      elsif !match[:child_name].to_s.empty? && normalize_name(member_name) != normalize_name(match[:child_name])
        notes << "Matched against parent/contact record: #{match[:contact_name]}"
      end

      output_rows << [
        member_name,
        matched_name,
        match[:parent_org],
        match[:site_url],
        confidence_label(match[:score]),
        match[:method],
        notes.join(' | '),
        '',
        '',
        '',
        '',
        ''
      ]
    else
      output_rows << [
        member_name,
        '',
        '',
        '',
        'Unmatched',
        'unmatched',
        'No likely match found in large sheet',
        '',
        '',
        '',
        '',
        ''
      ]
    end
  end

  csv_path = File.expand_path('CNPA URLS and opinion feeds.csv', Dir.pwd)
  CSV.open(csv_path, 'w', write_headers: false, force_quotes: true, row_sep: "\n") do |csv|
    output_rows.each do |row|
      csv << row
    end
  end

  xlsx_path = File.expand_path('CNPA URLS and opinion feeds.xlsx', Dir.pwd)
  build_workbook_xlsx(xlsx_path, 'CNPA URLS and opinion feeds', output_rows)

  summary = output_rows.drop(1).group_by { |row| row[4] }.transform_values(&:count)
  puts "Created #{xlsx_path}"
  puts "Created #{csv_path}"
  puts "Summary: #{summary.sort_by { |key, _| key }.map { |k, v| "#{k}=#{v}" }.join(', ')}"
end
