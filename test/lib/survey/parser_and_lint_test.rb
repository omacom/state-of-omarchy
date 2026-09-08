require "test_helper"

class Survey::ParserAndLintTest < ActiveSupport::TestCase
  test "the shipped edition parses and lints clean" do
    definition = Survey::Loader.load(Rails.configuration.x.survey.current_edition, reload: true)
    issues = Survey::Lint.run(definition)
    assert_empty issues.select { |i| i.level == "error" }, issues.map(&:message).join("\n")
    assert_equal "omarchy2026", definition.edition_id
    assert definition.sections.length > 1
  end

  test "bare yes/no option ids stay strings" do
    data = Survey::Yaml.load("sections:\n  - id: s\n    questions:\n      - id: q\n        type: single\n        options:\n          - id: yes\n            label: Yes\n          - id: no\n            label: No\n        showIf:\n          questionId: q\n          op: eq\n          values: [yes]\n")
    definition = Survey::Parser.parse(data)
    assert_equal %w[yes no], definition.question("q").option_ids
    assert_equal [ "yes" ], definition.question("q").show_if.values
  end

  test "parse raises only when sections are missing" do
    assert_raises(Survey::ParseError) { Survey::Parser.parse({ "survey" => {} }) }
    definition = Survey::Parser.parse({ "sections" => [ { "id" => "s", "questions" => [ { "id" => "q", "type" => "single", "options" => "nope" } ] } ] })
    assert_equal [], definition.question("q").options
  end

  test "lint catches duplicates, unknown types and broken showIf" do
    definition = build_definition([
      { "id" => "s", "title" => "S", "questions" => [
        { "id" => "a", "type" => "single", "prompt" => "A", "options" => [ { "id" => "x", "label" => "X" }, { "id" => "x", "label" => "X2" } ] },
        { "id" => "a", "type" => "text", "prompt" => "dup" },
        { "id" => "b", "type" => "hologram", "prompt" => "B" },
        { "id" => "c", "type" => "text", "prompt" => "C", "showIf" => { "questionId" => "a", "op" => "eq", "values" => [ "missing" ] } },
        { "id" => "d", "type" => "text", "prompt" => "D", "showIf" => { "questionId" => "ghost", "op" => "eq", "values" => [ "x" ] } },
        { "id" => "e", "type" => "multiple", "prompt" => "E", "options" => [ { "id" => "o", "label" => "O" } ], "exclusiveOptions" => [ "nope" ], "limit" => 0 },
        { "id" => "f", "type" => "scale", "prompt" => "F", "min" => 5, "max" => 1 }
      ] }
    ])
    messages = Survey::Lint.run(definition).select { |i| i.level == "error" }.map(&:message)
    assert_includes messages, "question a (section s) has duplicate option id: x"
    assert_includes messages, "duplicate question id: a (sections s, s)"
    assert_includes messages, "question b (section s) has unknown type \"hologram\" (no renderer registered)"
    assert_includes messages, "question c (section s) showIf value \"missing\" is not an option of a"
    assert_includes messages, "question d (section s) showIf references unknown question: ghost"
    assert_includes messages, "question e (section s) exclusiveOptions references unknown option: nope"
    assert_includes messages, "question e (section s) has invalid limit: 0"
    assert_includes messages, "question f (section s) has invalid min/max: 5..1"
  end

  test "loader lists editions and rejects unknown ones" do
    assert_includes Survey::Loader.editions, "2026"
    assert_raises(Survey::UnknownEditionError) { Survey::Loader.load("1999") }
  end
end
