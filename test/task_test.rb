using_task_library "iodrivers_base"
require "iodrivers_base/orogen_test_helpers"

using_task_library "water_probe_acquanativa_ap3"
import_types_from "water_probe_acquanativa_ap3"

describe OroGen.water_probe_acquanativa_ap3.Task do
    include IODriversBase::OroGenTestHelpers

    run_live
    attr_reader :task
    before do
        @task = syskit_deploy(
            OroGen.water_probe_acquanativa_ap3.Task
                  .deployed_as_unmanaged("water_probe_acquanativa_ap3_test")
        )
    end

    describe "test component configure" do
        it "checks for io_port setting obligatoriness" do
            task.properties.device_address = 0
            expect_execution.scheduler(true).to { fail_to_start task }
        end

        it "cheks for device address setting obligatoriness" do
            task.properties.io_port = "serial:///dev/ttyDUMMY:9600"
            expect_execution.scheduler(true).to { fail_to_start task }
        end
    end
end
