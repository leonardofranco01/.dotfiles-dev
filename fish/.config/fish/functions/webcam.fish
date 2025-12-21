function webcam
    set port "8080"
    set manual_ip $argv[1]

    # Module Handling
    if not lsmod | grep -q "v4l2loopback"
        echo "Module not found. Loading v4l2loopback..."
        if not sudo modprobe v4l2loopback exclusive_caps=1 card_label="AndroidCam"
            echo "Error: Failed to load kernel module."
            return 1
        end
    end

    # IP Resolution
    if test -n "$manual_ip"
        set target_ip "$manual_ip"
    else
        echo "No IP provided. Scanning network for open port $port..."
        
        set subnet (ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n 1)
        
        # Use grep to ensure we only look at lines where port 8080 is explicitly open.
        # This prevents picking up headers like "# Nmap scan initiated".
        set target_ip (nmap -p $port --open -oG - $subnet | grep "$port/open" | awk '{print $2}' | head -n 1)
        
        if test -z "$target_ip"
            echo "Error: Could not find any device with port $port open on $subnet."
            return 1
        end
        echo "Auto-detected device at: $target_ip"
    end

    # Validation
    # max time 2s to prevent hanging if the IP exists but rejects connections
    if not curl --output /dev/null --silent --head --fail --max-time 2 "http://$target_ip:$port/video"
        echo "Error: Found IP $target_ip, but cannot reach /video endpoint."
        return 1
    end

    # Execution
    echo "Starting webcam stream from http://$target_ip:$port/video..."
    echo "Press Ctrl+C to stop."
    
    ffmpeg -hide_banner -loglevel error \
        -i "http://$target_ip:$port/video" \
        -vf format=yuv420p \
        -f v4l2 /dev/video0
end