defmodule Vaisto.StdFileTest do
  use ExUnit.Case
  alias Vaisto.Runner

  # Load Std.File module before tests
  setup_all do
    prelude = File.read!("std/prelude.va")
    std_file_source = File.read!("std/File.va")
    full_source = prelude <> "\n\n" <> std_file_source
    # Module must be :"Std.File" to match import resolution
    {:ok, _} = Runner.compile_and_load(full_source, :"Std.File")
    :ok
  end

  describe "path operations" do
    test "path-join combines two paths" do
      source = """
      (import Std.File)
      (Std.File/path-join "foo" "bar")
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :PathJoin1)
      assert Runner.call(mod, :main) == "foo/bar"
    end

    test "path-join-all combines list of paths" do
      source = """
      (import Std.File)
      (Std.File/path-join-all (list "foo" "bar" "baz"))
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :PathJoinAll)
      assert Runner.call(mod, :main) == "foo/bar/baz"
    end

    test "dirname extracts directory" do
      source = """
      (import Std.File)
      (Std.File/dirname "/foo/bar/baz.txt")
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :Dirname)
      assert Runner.call(mod, :main) == "/foo/bar"
    end

    test "basename extracts filename" do
      source = """
      (import Std.File)
      (Std.File/basename "/foo/bar/baz.txt")
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :Basename)
      assert Runner.call(mod, :main) == "baz.txt"
    end

    test "extension extracts file extension" do
      source = """
      (import Std.File)
      (Std.File/extension "/foo/bar/baz.txt")
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :Extension)
      assert Runner.call(mod, :main) == ".txt"
    end

    test "rootname removes extension" do
      source = """
      (import Std.File)
      (Std.File/rootname "/foo/bar/baz.txt")
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :Rootname)
      assert Runner.call(mod, :main) == "/foo/bar/baz"
    end
  end

  describe "file I/O" do
    setup do
      # Create a temp directory for tests
      tmp_dir = System.tmp_dir!()
      test_dir = Path.join(tmp_dir, "vaisto_file_test_#{:rand.uniform(100000)}")
      File.mkdir_p!(test_dir)
      on_exit(fn -> File.rm_rf!(test_dir) end)
      {:ok, test_dir: test_dir}
    end

    test "write-file and read-file round trip", %{test_dir: test_dir} do
      test_file = Path.join(test_dir, "test.txt")
      source = """
      (import Std.File)
      (defn test-write-read [path]
        (do
          (Std.File/write-file path "hello world")
          (Std.File/read-file path)))
      (test-write-read "#{test_file}")
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :WriteRead)
      result = Runner.call(mod, :main)
      assert {:Ok, "hello world"} = result
    end

    test "read-lines splits file into lines", %{test_dir: test_dir} do
      test_file = Path.join(test_dir, "lines.txt")
      # Pre-create file with known content
      File.write!(test_file, "line1\nline2\nline3")

      source = """
      (import Std.File)
      (Std.File/read-lines "#{test_file}")
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :ReadLines)
      result = Runner.call(mod, :main)
      assert {:Ok, lines} = result
      assert lines == ["line1", "line2", "line3"]
    end

    test "append adds to existing file", %{test_dir: test_dir} do
      test_file = Path.join(test_dir, "append.txt")
      source = """
      (import Std.File)
      (defn test-append [path]
        (do
          (Std.File/write-file path "first")
          (Std.File/append path "second")
          (Std.File/read-file path)))
      (test-append "#{test_file}")
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :Append)
      result = Runner.call(mod, :main)
      assert {:Ok, "firstsecond"} = result
    end

    test "exists? returns true for existing file", %{test_dir: test_dir} do
      test_file = Path.join(test_dir, "exists.txt")
      File.write!(test_file, "content")

      source = """
      (import Std.File)
      (Std.File/exists? "#{test_file}")
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :Exists1)
      assert Runner.call(mod, :main) == true
    end

    test "exists? returns false for non-existing file" do
      source = """
      (import Std.File)
      (Std.File/exists? "/nonexistent/path/file.txt")
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :Exists2)
      assert Runner.call(mod, :main) == false
    end

    test "copy duplicates a file", %{test_dir: test_dir} do
      src = Path.join(test_dir, "src.txt")
      dst = Path.join(test_dir, "dst.txt")
      File.write!(src, "copy me")

      source = """
      (import Std.File)
      (defn test-copy []
        (do
          (Std.File/copy "#{src}" "#{dst}")
          (Std.File/read-file "#{dst}")))
      (test-copy)
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :Copy)
      result = Runner.call(mod, :main)
      assert {:Ok, "copy me"} = result
    end

    test "rename moves a file", %{test_dir: test_dir} do
      old_path = Path.join(test_dir, "old.txt")
      new_path = Path.join(test_dir, "new.txt")
      File.write!(old_path, "move me")

      source = """
      (import Std.File)
      (defn test-rename []
        (do
          (Std.File/rename "#{old_path}" "#{new_path}")
          (list (Std.File/exists? "#{old_path}") (Std.File/exists? "#{new_path}"))))
      (test-rename)
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :Rename)
      result = Runner.call(mod, :main)
      assert [false, true] = result
    end

    test "delete removes a file", %{test_dir: test_dir} do
      test_file = Path.join(test_dir, "delete.txt")
      File.write!(test_file, "delete me")

      source = """
      (import Std.File)
      (defn test-delete []
        (do
          (Std.File/delete "#{test_file}")
          (Std.File/exists? "#{test_file}")))
      (test-delete)
      """
      assert {:ok, mod} = Runner.compile_and_load(source, :Delete)
      assert Runner.call(mod, :main) == false
    end
  end
end
