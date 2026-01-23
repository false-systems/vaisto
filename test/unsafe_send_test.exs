defmodule Vaisto.UnsafeSendTest do
  use ExUnit.Case, async: true

  alias Vaisto.Runner

  describe "unsafe send (!!)" do
    test "!! accepts any message to typed PID" do
      # Even invalid messages should pass with !!
      code = """
      (process counter 0
        :inc (+ state 1))

      (defn main []
        (!! (spawn counter 0) :totally-invalid-message))
      """
      assert {:ok, _} = Runner.compile_and_load(code, :UnsafeSendAnyMsg)
    end

    test "!! accepts valid message to typed PID" do
      code = """
      (process counter 0
        :inc (+ state 1))

      (defn main []
        (!! (spawn counter 0) :inc))
      """
      assert {:ok, _} = Runner.compile_and_load(code, :UnsafeSendValidMsg)
    end

    test "!! rejects non-PID first argument" do
      code = """
      (defn main []
        (!! 42 :message))
      """
      result = Runner.compile_and_load(code, :UnsafeSendNonPid)
      assert {:error, %Vaisto.Error{message: msg}} = result
      assert msg =~ "non-pid" or msg =~ "PID"
    end

    test "!! accepts untyped PID parameter" do
      # When a PID comes from a parameter (untyped), !! should allow it
      # The function takes a PID as a parameter - its type is :any
      code = """
      (process echo 0
        :ping state)

      (defn send_msg [pid]
        (!! pid :ping))

      (defn main []
        (send_msg (spawn echo 0)))
      """
      assert {:ok, _} = Runner.compile_and_load(code, :UnsafeSendUntypedPid)
    end

    test "! rejects invalid message (for comparison)" do
      # Verify that ! still validates - this is the safe version
      code = """
      (process counter 0
        :inc (+ state 1))

      (defn main []
        (! (spawn counter 0) :invalid))
      """
      result = Runner.compile_and_load(code, :SafeSendInvalid)
      assert {:error, %Vaisto.Error{note: note}} = result
      assert note =~ "does not accept"
    end
  end
end