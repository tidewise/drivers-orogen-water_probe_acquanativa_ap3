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

    attr_reader :probe_measurements_raw
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

        @probe_measurements_raw = [756, 85, 200, 646, 156, 126, 1256, 32, 40, 3, 500, 1, 76]
        modbus_set(registers["dissolved_oxygen"], @probe_measurements_raw[0])
        modbus_set(registers["dissolved_oxygen_sat"], @probe_measurements_raw[1])
        modbus_set(registers["temperature"], @probe_measurements_raw[2])
        modbus_set(registers["ph"], @probe_measurements_raw[3])
        modbus_set(registers["conductivity"], @probe_measurements_raw[4])
        modbus_set(registers["salinity"], @probe_measurements_raw[5])
        modbus_set(registers["dissolved_solids"], @probe_measurements_raw[6])
        modbus_set(registers["specific_gravity"], @probe_measurements_raw[7])
        modbus_set(registers["orp"], @probe_measurements_raw[8])
        modbus_set(registers["turbity"], @probe_measurements_raw[9])
        modbus_set(registers["height"], @probe_measurements_raw[10])
        modbus_set(registers["latitude"], @probe_measurements_raw[11])
        modbus_set(registers["longitude"], @probe_measurements_raw[12])
    end

    def get_expected_sample
        sample = Types.water_probe_acquanativa_ap3.ProbeMeasurements.new
        sample.concentration = @probe_measurements_raw[0] * 1e-5
        sample.saturation = @probe_measurements_raw[1] * 1e-2
        sample.temperature.kelvin = 275.15;
        sample.ph = @probe_measurements_raw[3] * 1e-2;
        sample.conductivity = @probe_measurements_raw[4] * 1e-10;
        sample.salinity = @probe_measurements_raw[5] * 1e-2
        sample.dissolved_solids = @probe_measurements_raw[6] * 1e-2
        sample.specific_gravity = @probe_measurements_raw[7] * 1e-2
        sample.ORP = @probe_measurements_raw[8] * 1e-3
        sample.turbity = @probe_measurements_raw[9]
        sample.height = @probe_measurements_raw[10]
        sample.latitude = @probe_measurements_raw[11] * 1e-2
        sample.longitude = @probe_measurements_raw[12] * 1e-2
        sample
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

        it "check if the sample timestamp is updated" do
            read_request_time = Time.now
            sample = modbus_expect_execution(@writer, @reader) do
                mock_all_sensor_registers
            end.to do
                have_one_new_sample task.probe_measurements_port
            end
            now = Time.now
            dt = now - read_request_time
            assert_in_delta(now, sample.time, dt)
        end

        it "successfully read all measurements" do
            sample = modbus_expect_execution(@writer, @reader) do
                mock_all_sensor_registers
            end.to do
                have_one_new_sample task.probe_measurements_port
            end

            expected_sample = get_expected_sample
            expected_sample.time = sample.time

            assert_equal sample, expected_sample
        end

        it "fail when measurements are not avaiable" do
            modbus_expect_execution(@writer, @reader) do
                have_no_new_sample task.probe_measurements_port, at_least_during: 0.5
            end
        end
    end
end
