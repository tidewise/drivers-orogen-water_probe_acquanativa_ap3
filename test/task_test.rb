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

    def mock_all_sensor_registers
        registers = {
            "dissolved_oxygen" => 0,
            "dissolved_oxygen_sat" => 1,
            "temperature" => 2,
            "ph" => 3,
            "conductivity" => 4,
            "salinity" => 5,
            "dissolved_solids" => 6,
            "specific_gravity" => 7,
            "orp" => 8,
            "turbity" => 9,
            "height" => 10,
            "latitude" => 11,
            "longitude" => 12
        }

        max_value = 2**16
        modbus_set(registers["dissolved_oxygen"], rand(max_value))
        modbus_set(registers["dissolved_oxygen_sat"], rand(max_value))
        modbus_set(registers["temperature"], rand(max_value))
        modbus_set(registers["ph"], rand(max_value))
        modbus_set(registers["conductivity"], rand(max_value))
        modbus_set(registers["salinity"], rand(max_value))
        modbus_set(registers["dissolved_solids"], rand(max_value))
        modbus_set(registers["specific_gravity"], rand(max_value))
        modbus_set(registers["orp"], rand(max_value))
        modbus_set(registers["turbity"], rand(max_value))
        modbus_set(registers["height"], rand(max_value))
        modbus_set(registers["latitude"], rand(max_value))
        modbus_set(registers["longitude"], rand(max_value))
    end

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

    describe "getting new measurements" do
        before do
            task.properties.device_address = 57
            task.properties.io_read_timeout = Time.at(2)
            modbus_configure_and_start
        end

        it "successfully read all measurements" do
            modbus_expect_execution(@writer, @reader) do
                mock_all_sensor_registers
            end.to do
                have_one_new_sample task.probe_measurements_port
            end
        end

        it "fail when measurements are not avaiable" do
            modbus_expect_execution(@writer, @reader) do
                have_no_new_sample task.probe_measurements_port, at_least_during: 0.5
            end
        end

    end
end
