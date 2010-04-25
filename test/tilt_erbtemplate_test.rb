require 'contest'
require 'tilt'
require 'erb'

class ERBTemplateTest < Test::Unit::TestCase
  test "registered for '.erb' files" do
    assert_equal Tilt::ERBTemplate, Tilt['test.erb']
    assert_equal Tilt::ERBTemplate, Tilt['test.html.erb']
  end

  test "registered for '.rhtml' files" do
    assert_equal Tilt::ERBTemplate, Tilt['test.rhtml']
  end

  test "loading and evaluating templates on #render" do
    template = Tilt::ERBTemplate.new { |t| "Hello World!" }
    assert_equal "Hello World!", template.render
  end

  test "passing locals" do
    template = Tilt::ERBTemplate.new { 'Hey <%= name %>!' }
    assert_equal "Hey Joe!", template.render(Object.new, :name => 'Joe')
  end

  test "evaluating in an object scope" do
    template = Tilt::ERBTemplate.new { 'Hey <%= @name %>!' }
    scope = Object.new
    scope.instance_variable_set :@name, 'Joe'
    assert_equal "Hey Joe!", template.render(scope)
  end

  test "exposing the buffer to the template" do
    $exposed_template = nil
    Tilt::ERBTemplate.expose_buffer_variable!
    template = Tilt::ERBTemplate.new { '<% $exposed_template = @_erbout %>hey' }
    template.render
    assert_not_nil $exposed_template
    assert_equal $exposed_template, 'hey'
  end

  test "passing a block for yield" do
    template = Tilt::ERBTemplate.new { 'Hey <%= yield %>!' }
    assert_equal "Hey Joe!", template.render { 'Joe' }
  end

  test "backtrace file and line reporting without locals" do
    data = File.read(__FILE__).split("\n__END__\n").last
    fail unless data[0] == ?<
    template = Tilt::ERBTemplate.new('test.erb', 11) { data }
    begin
      template.render
      fail 'should have raised an exception'
    rescue => boom
      assert_kind_of NameError, boom
      line = boom.backtrace.first
      file, line, meth = line.split(":")
      assert_equal 'test.erb', file
      assert_equal '13', line
    end
  end

  test "backtrace file and line reporting with locals" do
    data = File.read(__FILE__).split("\n__END__\n").last
    fail unless data[0] == ?<
    template = Tilt::ERBTemplate.new('test.erb', 1) { data }
    begin
      template.render(nil, :name => 'Joe', :foo => 'bar')
      fail 'should have raised an exception'
    rescue => boom
      assert_kind_of RuntimeError, boom
      line = boom.backtrace.first
      file, line, meth = line.split(":")
      assert_equal 'test.erb', file
      assert_equal '6', line
    end
  end

  test "default non-stripping trim mode" do
    template = Tilt.new('test.erb', 1) { "\n<%= 1 + 1 %>\n" }
    assert_equal "\n2\n", template.render
  end

  test "stripping trim mode" do
    template = Tilt.new('test.erb', 1, :trim => '-') { "\n<%= 1 + 1 -%>\n" }
    assert_equal "\n2", template.render
  end

  test "shorthand whole line syntax trim mode" do
    template = Tilt.new('test.erb', :trim => '%') { "\n% if true\nhello\n%end\n" }
    assert_equal "\nhello\n", template.render
  end

  test "using an instance variable as the outvar" do
    template = Tilt::ERBTemplate.new(nil, :outvar => '@buf') { "<%= 1 + 1 %>" }
    scope = Object.new
    scope.instance_variable_set(:@buf, 'original value')
    assert_equal '2', template.render(scope)
    assert_equal 'original value', scope.instance_variable_get(:@buf)
  end
end

class CompiledERBTemplateTest < Test::Unit::TestCase
  def teardown
    GC.start
  end

  class Scope
    include Tilt::CompileSite
  end

  test "compiling template source to a method" do
    template = Tilt::ERBTemplate.new { |t| "Hello World!" }
    template.render(Scope.new)
    method_name = template.send(:compiled_method_name, [])
    method_name = method_name.to_sym if Symbol === Kernel.methods.first
    assert Tilt::CompileSite.instance_methods.include?(method_name),
      "CompileSite.instance_methods.include?(#{method_name.inspect})"
    assert Scope.new.respond_to?(method_name),
      "scope.respond_to?(#{method_name.inspect})"
  end

  test "loading and evaluating templates on #render" do
    template = Tilt::ERBTemplate.new { |t| "Hello World!" }
    assert_equal "Hello World!", template.render(Scope.new)
    assert_equal "Hello World!", template.render(Scope.new)
  end

  test "passing locals" do
    template = Tilt::ERBTemplate.new { 'Hey <%= name %>!' }
    assert_equal "Hey Joe!", template.render(Scope.new, :name => 'Joe')
  end

  test "evaluating in an object scope" do
    template = Tilt::ERBTemplate.new { 'Hey <%= @name %>!' }
    scope = Scope.new
    scope.instance_variable_set :@name, 'Joe'
    assert_equal "Hey Joe!", template.render(scope)
    scope.instance_variable_set :@name, 'Jane'
    assert_equal "Hey Jane!", template.render(scope)
  end

  test "passing a block for yield" do
    template = Tilt::ERBTemplate.new { 'Hey <%= yield %>!' }
    assert_equal "Hey Joe!", template.render(Scope.new) { 'Joe' }
    assert_equal "Hey Jane!", template.render(Scope.new) { 'Jane' }
  end

  test "backtrace file and line reporting without locals" do
    data = File.read(__FILE__).split("\n__END__\n").last
    fail unless data[0] == ?<
    template = Tilt::ERBTemplate.new('test.erb', 11) { data }
    begin
      template.render(Scope.new)
      fail 'should have raised an exception'
    rescue => boom
      assert_kind_of NameError, boom
      line = boom.backtrace.first
      file, line, meth = line.split(":")
      assert_equal 'test.erb', file
      assert_equal '13', line
    end
  end

  test "backtrace file and line reporting with locals" do
    data = File.read(__FILE__).split("\n__END__\n").last
    fail unless data[0] == ?<
    template = Tilt::ERBTemplate.new('test.erb') { data }
    begin
      template.render(Scope.new, :name => 'Joe', :foo => 'bar')
      fail 'should have raised an exception'
    rescue => boom
      assert_kind_of RuntimeError, boom
      line = boom.backtrace.first
      file, line, meth = line.split(":")
      assert_equal 'test.erb', file
      assert_equal '6', line
    end
  end

  test "default non-stripping trim mode" do
    template = Tilt.new('test.erb') { "\n<%= 1 + 1 %>\n" }
    assert_equal "\n2\n", template.render(Scope.new)
  end

  test "stripping trim mode" do
    template = Tilt.new('test.erb', :trim => '-') { "\n<%= 1 + 1 -%>\n" }
    assert_equal "\n2", template.render(Scope.new)
  end

  test "shorthand whole line syntax trim mode" do
    template = Tilt.new('test.erb', :trim => '%') { "\n% if true\nhello\n%end\n" }
    assert_equal "\nhello\n", template.render(Scope.new)
  end
end

__END__
<html>
<body>
  <h1>Hey <%= name %>!</h1>


  <p><% fail %></p>
</body>
</html>
