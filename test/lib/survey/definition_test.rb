require "test_helper"

# Pure-engine tests for the generic rules: visibility, validation, progress.
class Survey::DefinitionTest < ActiveSupport::TestCase
  def definition
    @definition ||= build_definition([
      { "id" => "a", "title" => "A", "questions" => [
        { "id" => "single_q", "type" => "single", "required" => true, "prompt" => "S",
          "options" => [ { "id" => "yes", "label" => "Yes" }, { "id" => "no", "label" => "No" } ], "allowOther" => true },
        { "id" => "multi_q", "type" => "multiple", "prompt" => "M", "limit" => 2, "exclusiveOptions" => [ "none" ],
          "options" => [ { "id" => "x", "label" => "X" }, { "id" => "y", "label" => "Y" }, { "id" => "z", "label" => "Z" }, { "id" => "none", "label" => "None" } ] },
        { "id" => "dep_q", "type" => "text", "prompt" => "D", "maxLength" => 5,
          "showIf" => { "questionId" => "single_q", "op" => "eq", "values" => [ "yes" ] } },
        { "id" => "scale_q", "type" => "scale", "prompt" => "Sc", "min" => 1, "max" => 5 },
        { "id" => "list_q", "type" => "text_list", "prompt" => "L", "limit" => 2 },
        { "id" => "country_q", "type" => "country", "prompt" => "C" },
        { "id" => "future_q", "type" => "hologram", "prompt" => "F" }
      ] }
    ])
  end

  def q(id) = definition.question(id)

  test "showIf eq hides until the target matches" do
    assert_not definition.visible?(q("dep_q"), {})
    assert_not definition.visible?(q("dep_q"), { "single_q" => Survey::Value.single("no") })
    assert definition.visible?(q("dep_q"), { "single_q" => Survey::Value.single("yes") })
  end

  test "showIf includesAny matches any selected id" do
    d = build_definition([ { "id" => "s", "title" => "S", "questions" => [
      { "id" => "m", "type" => "multiple", "prompt" => "", "options" => [ { "id" => "a", "label" => "A" }, { "id" => "b", "label" => "B" } ] },
      { "id" => "t", "type" => "text", "prompt" => "", "showIf" => { "questionId" => "m", "op" => "includesAny", "values" => [ "b" ] } }
    ] } ])
    assert_not d.visible?(d.question("t"), { "m" => Survey::Value.multiple([ "a" ]) })
    assert d.visible?(d.question("t"), { "m" => Survey::Value.multiple([ "a", "b" ]) })
  end

  test "required questions report emptiness only when enforced" do
    assert_equal "This question is required.", definition.validate(q("single_q"), nil)
    assert_nil definition.validate(q("single_q"), nil, enforce_required: false)
    assert_nil definition.validate(q("multi_q"), Survey::Value.empty)
  end

  test "single validation: listed option, other needs text" do
    assert_nil definition.validate(q("single_q"), Survey::Value.single("yes"))
    assert_equal "Please choose a valid option.", definition.validate(q("single_q"), Survey::Value.single("nope"))
    assert_equal "Please specify your answer.", definition.validate(q("single_q"), Survey::Value.single("other", other: "  "))
    assert_nil definition.validate(q("single_q"), Survey::Value.single("other", other: "USB"))
  end

  test "multiple validation: limit and exclusive options" do
    assert_nil definition.validate(q("multi_q"), Survey::Value.multiple([ "x", "y" ]))
    assert_equal "Select at most 2.", definition.validate(q("multi_q"), Survey::Value.multiple([ "x", "y", "z" ]))
    assert_equal "“None” can’t be combined with other options.", definition.validate(q("multi_q"), Survey::Value.multiple([ "x", "none" ]))
    assert_nil definition.validate(q("multi_q"), Survey::Value.multiple([ "none" ]))
    assert_equal "Please choose valid options.", definition.validate(q("multi_q"), Survey::Value.multiple([ "other" ]))
  end

  test "scale validation stays within min..max" do
    assert_nil definition.validate(q("scale_q"), Survey::Value.number(3))
    assert_equal "Please pick a value between 1 and 5.", definition.validate(q("scale_q"), Survey::Value.number(9))
  end

  test "text and list limits" do
    assert_equal "Keep it under 5 characters.", definition.validate(q("dep_q"), Survey::Value.text("toolong"))
    assert_equal "At most 2 entries.", definition.validate(q("list_q"), Survey::Value.list([ "a", "b", "c" ]))
    assert_nil definition.validate(q("list_q"), Survey::Value.list([ "a", "", "  " ]))
  end

  test "unknown types are never answered, validated or counted" do
    assert_not definition.answered?(q("future_q"), Survey::Value.text("x"))
    assert_nil definition.validate(q("future_q"), Survey::Value.text("x"))
    assert_equal 0, definition.completion({})
  end

  test "completion counts visible known questions only" do
    answers = { "single_q" => Survey::Value.single("no"), "scale_q" => Survey::Value.number(2) }
    # dep_q hidden -> 5 visible known questions, 2 answered
    assert_equal 40, definition.completion(answers)
    answers["single_q"] = Survey::Value.single("yes")
    assert_equal 33, definition.completion(answers) # dep_q now visible -> 6
  end

  test "section completeness is required-only, counts include optional" do
    section = definition.sections.first
    assert_not definition.section_complete?(section, {})
    assert definition.section_complete?(section, { "single_q" => Survey::Value.single("no") })
    assert_equal({ answered: 1, total: 5 }, definition.section_counts(section, { "single_q" => Survey::Value.single("no") }))
  end

  test "value coercion from form params by type" do
    assert_equal Survey::Value.single("yes"), Survey::Value.from_params(q("single_q"), { "option_id" => "yes" })
    assert Survey::Value.from_params(q("single_q"), { "option_id" => "" }).empty?
    assert_equal Survey::Value.multiple([ "x", "y" ]), Survey::Value.from_params(q("multi_q"), { "option_ids" => [ "x", "x", "y" ] })
    assert_equal Survey::Value.number(3), Survey::Value.from_params(q("scale_q"), { "value" => "3" })
    assert Survey::Value.from_params(q("scale_q"), { "value" => "" }).empty?
    assert_equal Survey::Value.list([ "a", "" ]), Survey::Value.from_params(q("list_q"), { "items" => [ "a", "" ] })
    assert Survey::Value.from_params(q("list_q"), { "items" => [ "", " " ] }).empty?
    assert_equal Survey::Value.country("tr"), Survey::Value.from_params(q("country_q"), { "code" => "tr" })
    assert Survey::Value.from_params(q("future_q"), { "anything" => true }).empty?
    assert Survey::Value.from_params(q("single_q"), "not a hash").empty?
  end
end
