#!/bin/bash

################################################################################
# System Monitoring Script with Real-time Alerts and Logging
# CS315 - Operating System Final Project
# Purpose: Monitor CPU, Memory, and Disk usage with automated alerts
################################################################################

# Default threshold values (in percentage)
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=80

# Log file location
LOG_DIR="${HOME}/logs"
LOG_FILE="${LOG_DIR}/system_monitor.log"

# Interval for monitoring (in seconds) - 0 means run once
MONITOR_INTERVAL=0

################################################################################
# Color codes for output
################################################################################
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Function: Display usage information
################################################################################
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -c, --cpu-threshold NUM          Set CPU threshold percentage (default: 80)
    -m, --memory-threshold NUM       Set memory threshold percentage (default: 80)
    -d, --disk-threshold NUM         Set disk threshold percentage (default: 80)
    -i, --interval NUM               Set monitoring interval in seconds (0 = run once)
    -p, --partition PATH             Disk partition to monitor (default: /)
    -h, --help                       Display this help message

EXAMPLES:
    $0 --cpu-threshold 75 --interval 10
    $0 -c 70 -m 85 -p /dev/sda1
    $0 --help

EOF
    exit 0
}

################################################################################
# Function: Initialize log directory and file
################################################################################
init_logging() {
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" || { echo "Error: Cannot create log directory $LOG_DIR"; exit 1; }
    fi
    
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" || { echo "Error: Cannot create log file $LOG_FILE"; exit 1; }
    fi
}

################################################################################
# Function: Log output with timestamp
################################################################################
log_output() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

################################################################################
# Function: Print colored console output
################################################################################
print_colored_output() {
    local level="$1"
    local message="$2"
    
    case "$level" in
        CRITICAL)
            echo -e "${RED}[CRITICAL]${NC} ${message}"
            ;;
        WARNING)
            echo -e "${YELLOW}[WARNING]${NC} ${message}"
            ;;
        OK)
            echo -e "${GREEN}[OK]${NC} ${message}"
            ;;
        INFO)
            echo -e "${BLUE}[INFO]${NC} ${message}"
            ;;
        *)
            echo "${message}"
            ;;
    esac
}

################################################################################
# Function: Get CPU usage percentage
################################################################################
get_cpu_usage() {
    # Using top command to get CPU usage (average across all cores)
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
    
    if [ -z "$cpu_usage" ]; then
        echo "0"
    else
        echo "$cpu_usage"
    fi
}

################################################################################
# Function: Get memory usage percentage
################################################################################
get_memory_usage() {
    # Using free command to calculate memory percentage
    local mem_info=$(free | grep "^Mem:")
    local total=$(echo "$mem_info" | awk '{print $2}')
    local used=$(echo "$mem_info" | awk '{print $3}')
    
    if [ "$total" -eq 0 ]; then
        echo "0"
        return 1
    fi
    
    local mem_percentage=$(( (used * 100) / total ))
    echo "$mem_percentage"
}

################################################################################
# Function: Get disk usage percentage for a partition
################################################################################
get_disk_usage() {
    local partition="$1"
    
    # Validate partition exists
    if ! df "$partition" > /dev/null 2>&1; then
        echo "Error: Invalid partition $partition" >&2
        return 1
    fi
    
    # Get disk usage percentage
    local disk_usage=$(df "$partition" | awk 'NR==2 {print int($5)}')
    
    if [ -z "$disk_usage" ]; then
        echo "0"
    else
        echo "$disk_usage"
    fi
}

################################################################################
# Function: Get top 5 CPU-consuming processes
################################################################################
get_top_processes() {
    echo "Top 5 CPU-consuming processes:"
    ps aux --sort=-%cpu | head -n 6 | tail -n +2 | awk '{printf "  %-8s %-6s %-6s %s\n", $1, $3"%", $11, $12}'
}

################################################################################
# Function: Check threshold and generate alert
################################################################################
check_threshold_and_alert() {
    local resource_name="$1"
    local current_value="$2"
    local threshold="$3"
    
    if [ "$current_value" -gt "$threshold" ]; then
        local alert_msg="${resource_name} usage is CRITICAL: ${current_value}% (threshold: ${threshold}%)"
        print_colored_output "CRITICAL" "$alert_msg"
        log_output "ALERT - $alert_msg"
        return 1  # Alert triggered
    elif [ "$current_value" -gt $(( threshold - 10 )) ]; then
        local warn_msg="${resource_name} usage is elevated: ${current_value}% (threshold: ${threshold}%)"
        print_colored_output "WARNING" "$warn_msg"
        log_output "WARNING - $warn_msg"
        return 0  # Warning only
    else
        local ok_msg="${resource_name} usage is normal: ${current_value}%"
        print_colored_output "OK" "$ok_msg"
        log_output "OK - $ok_msg"
        return 0
    fi
}

################################################################################
# Function: Perform complete system check
################################################################################
perform_system_check() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo ""
    echo "============================================================"
    print_colored_output "INFO" "System Monitoring Report - $timestamp"
    echo "============================================================"
    
    log_output "========== System Check Started =========="
    
    # Check CPU
    local cpu=$(get_cpu_usage)
    if [ $? -eq 0 ]; then
        check_threshold_and_alert "CPU" "$cpu" "$CPU_THRESHOLD"
    else
        print_colored_output "WARNING" "Failed to get CPU usage"
        log_output "ERROR - Failed to retrieve CPU usage"
    fi
    
    echo ""
    
    # Check Memory
    local mem=$(get_memory_usage)
    if [ $? -eq 0 ]; then
        check_threshold_and_alert "Memory" "$mem" "$MEMORY_THRESHOLD"
    else
        print_colored_output "WARNING" "Failed to get memory usage"
        log_output "ERROR - Failed to retrieve memory usage"
    fi
    
    echo ""
    
    # Check Disk
    local disk=$(get_disk_usage "$DISK_PARTITION")
    if [ $? -eq 0 ]; then
        check_threshold_and_alert "Disk" "$disk" "$DISK_THRESHOLD"
    else
        print_colored_output "WARNING" "Failed to get disk usage for $DISK_PARTITION"
        log_output "ERROR - Failed to retrieve disk usage for $DISK_PARTITION"
    fi
    
    echo ""
    
    # Display top processes
    print_colored_output "INFO" "$(get_top_processes)"
    log_output "Top processes retrieved"
    
    echo "============================================================"
    log_output "========== System Check Completed =========="
    echo ""
}

################################################################################
# Function: Parse command-line arguments
################################################################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--cpu-threshold)
                if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 0 ] || [ "$2" -gt 100 ]; then
                    echo "Error: CPU threshold must be a number between 0-100"
                    exit 1
                fi
                CPU_THRESHOLD="$2"
                shift 2
                ;;
            -m|--memory-threshold)
                if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 0 ] || [ "$2" -gt 100 ]; then
                    echo "Error: Memory threshold must be a number between 0-100"
                    exit 1
                fi
                MEMORY_THRESHOLD="$2"
                shift 2
                ;;
            -d|--disk-threshold)
                if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 0 ] || [ "$2" -gt 100 ]; then
                    echo "Error: Disk threshold must be a number between 0-100"
                    exit 1
                fi
                DISK_THRESHOLD="$2"
                shift 2
                ;;
            -i|--interval)
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    echo "Error: Interval must be a positive number in seconds"
                    exit 1
                fi
                MONITOR_INTERVAL="$2"
                shift 2
                ;;
            -p|--partition)
                DISK_PARTITION="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Error: Unknown option $1"
                usage
                ;;
        esac
    done
}

################################################################################
# Main Script
################################################################################
main() {
    # Initialize logging
    init_logging
    
    # Parse command-line arguments
    parse_arguments "$@"
    
    # Set default partition if not specified
    DISK_PARTITION="${DISK_PARTITION:=/}"
    
    # Log script initialization
    log_output "System Monitor started with thresholds - CPU: ${CPU_THRESHOLD}%, Memory: ${MEMORY_THRESHOLD}%, Disk: ${DISK_THRESHOLD}%"
    
    # Run monitoring
    if [ "$MONITOR_INTERVAL" -eq 0 ]; then
        # Run once
        perform_system_check
    else
        # Run continuously at specified interval
        print_colored_output "INFO" "Monitoring system every ${MONITOR_INTERVAL} seconds (Press Ctrl+C to stop)"
        while true; do
            perform_system_check
            sleep "$MONITOR_INTERVAL"
        done
    fi
}

# Execute main function with all arguments
main "$@"