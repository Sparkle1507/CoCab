import math

def calculate_distance(lat1, lon1, lat2, lon2):
    # Earth radius in kilometers
    R = 6371.0 
    
    # Converting degrees to radians
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    
    # Haversine formula logic
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c

def check_ride_share(A, B, C, max_detour_km=2.0):
    # Calculate individual distances
    dist_A_to_C = calculate_distance(A[0], A[1], C[0], C[1])
    dist_A_to_B = calculate_distance(A[0], A[1], B[0], B[1])
    dist_B_to_C = calculate_distance(B[0], B[1], C[0], C[1])
    
    # Total distance if Driver picks up B on the way to C
    total_shared_distance = dist_A_to_B + dist_B_to_C
    
    # How much extra distance (detour) the driver has to travel
    detour = total_shared_distance - dist_A_to_C
    
    print(f"Direct route (A to C): {dist_A_to_C:.2f} km")
    print(f"Shared route (A -> B -> C): {total_shared_distance:.2f} km")
    print(f"Extra distance (Detour): {detour:.2f} km\n")
    
    # Check if the detour is within the acceptable limit
    if detour <= max_detour_km:
        return True
    else:
        return False

# Mock Coordinates (Latitude, Longitude)
point_A = (13.0827, 80.2707) # Start Location (e.g., Chennai Central)
point_C = (12.9716, 80.2496) # Drop Location (e.g., Thoraipakkam)
point_B = (13.0133, 80.2355) # Passenger 2 Location (e.g., Guindy)

print("Checking route match...\n")
is_match = check_ride_share(point_A, point_B, point_C)

if is_match:
    print("Result: Match Found! The ride can be shared.")
else:
    print("Result: No Match. The route detour is too long.")