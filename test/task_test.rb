using_task_library "iodrivers_base"
require "iodrivers_base/orogen_test_helpers"

require_relative "modbus_helpers.rb"

using_task_library "water_probe_acquanativa_ap3"
import_types_from "water_probe_acquanativa_ap3"


describe OroGen.water_probe_acquanativa_ap3.Task do
    include IODriversBase::OroGenTestHelpers

    run_live

    attr_reader :task
    attr_reader :reader
    attr_reader :writer

    include ModbusHelpers


    before do
        @task, @reader, @writer = iodrivers_base_prepare(
            OroGen.water_probe_acquanativa_ap3.Task
                . deployed_as("water_probe_acquanativa_ap3_test")
        )

        modbus_helpers_setup(@task, @reader, @writer)
    end

    describe "test component configure" do
        it "cheks for device address setting obligatoriness" do
            expect_execution.scheduler(true).to { fail_to_start task }
        end
    end

end
