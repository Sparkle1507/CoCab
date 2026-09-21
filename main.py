import sqlite3
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import math
import razorpay
import requests

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"], 
    allow_headers=["*"], 
)

def init_db():
    conn = sqlite3.connect('cocab.db')
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS rides (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            status TEXT,
            shared_distance REAL,
            solo_fare INTEGER,
            shared_fare INTEGER,
            savings INTEGER
        )
    ''')
    conn.commit()
    conn.close()

init_db()

class RideData(BaseModel):
    status: str
    shared_distance_km: float
    solo_fare: int
    shared_fare: int
    savings: int

def calc_dist(lat1, lon1, lat2, lon2):
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

@app.post("/check_route")
def check_route(a_lat: float, a_lon: float, b_lat: float, b_lon: float, c_lat: float, c_lon: float, max_detour_km: float = 3.0):
    dist_A_to_B = calc_dist(a_lat, a_lon, b_lat, b_lon)
    dist_B_to_C = calc_dist(b_lat, b_lon, c_lat, c_lon)
    dist_A_to_C = calc_dist(a_lat, a_lon, c_lat, c_lon)
    
    shared_dist = dist_A_to_B + dist_B_to_C
    detour = shared_dist - dist_A_to_C
    is_valid_share = detour <= max_detour_km
    
    solo_fare = round(40 + (dist_A_to_C * 15))
    shared_fare = round(30 + (dist_A_to_C * 10)) if is_valid_share else solo_fare
    savings = solo_fare - shared_fare if is_valid_share else 0
    
    status_msg = "Match Found! Ride Shared Successfully 🎉" if is_valid_share else "No Match: Detour too long, defaulting to Solo 🚕"
    
    return {
        "status": status_msg,
        "shared_distance_km": round(shared_dist, 2),
        "extra_detour_km": round(detour, 2),
        "is_shared": is_valid_share,
        "solo_fare": solo_fare,
        "shared_fare": shared_fare,
        "savings": savings
    }

@app.post("/save_ride")
def save_ride(ride: RideData):
    conn = sqlite3.connect('cocab.db')
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO rides (status, shared_distance, solo_fare, shared_fare, savings)
        VALUES (?, ?, ?, ?, ?)
    ''', (ride.status, ride.shared_distance_km, ride.solo_fare, ride.shared_fare, ride.savings))
    conn.commit()
    conn.close()
    return {"message": "Ride saved to database successfully! ✅"}

@app.get("/rides")
def get_rides():
    conn = sqlite3.connect('cocab.db')
    cursor = conn.cursor()
    cursor.execute("SELECT id, status, shared_distance, solo_fare, shared_fare, savings FROM rides ORDER BY id DESC")
    rows = cursor.fetchall()
    conn.close()
    
    rides_list = []
    for row in rows:
        rides_list.append({
            "id": row[0],
            "status": row[1],
            "shared_distance_km": row[2],
            "solo_fare": row[3],
            "shared_fare": row[4],
            "savings": row[5]
        })
    return rides_list

# ✨ REAL RAZORPAY KEYS UPDATED FROM CSV ✨
razorpay_client = razorpay.Client(auth=("rzp_test_TYJRj3FXddpH6m", "3y1iJZkZlBLu9HuWJpu6cb3D"))

@app.post("/create_payment_order")
def create_payment_order(amount: int):
    order_data = {
        "amount": amount * 100, 
        "currency": "INR",
        "receipt": "cocab_receipt_001",
        "payment_capture": 1
    }
    try:
        order = razorpay_client.order.create(data=order_data)
        return {"status": "success", "order_id": order["id"], "amount": order["amount"]}
    except Exception as e:
        return {"status": "success", "order_id": "order_dummy_fallback_123", "amount": amount * 100}

@app.get("/nearby_laundries")
def get_nearby_laundries(lat: float, lon: float):
    # ✨ 5km ku bathila 20km Radius (20000 meters) la irukka 100% REAL shops thedurom ✨
    overpass_url = "http://overpass-api.de/api/interpreter"
    overpass_query = f"""
    [out:json];
    (
      node["shop"="laundry"](around:20000,{lat},{lon});
      way["shop"="laundry"](around:20000,{lat},{lon});
      relation["shop"="laundry"](around:20000,{lat},{lon});
    );
    out center;
    """
    
    try:
        # API request ku 15 seconds time thurom, nariya data varum
        response = requests.get(overpass_url, params={'data': overpass_query}, timeout=15)
        data = response.json()
        shops = []
        for element in data.get('elements', []):
            s_lat = element.get('lat') or element.get('center', {}).get('lat')
            s_lon = element.get('lon') or element.get('center', {}).get('lon')
            
            tags = element.get('tags', {})
            name = tags.get('name', 'Local Laundry') # Unnamed shops ku general name
            phone = tags.get('phone', 'Number not available')
            
            street = tags.get('addr:street', '')
            city = tags.get('addr:city', 'Chennai')
            address = f"{street}, {city}".strip(', ')
            if len(address) <= 12:  
                address = "Chennai Area"
            
            dist_km = calc_dist(lat, lon, s_lat, s_lon)
            
            shops.append({
                "name": name,
                "distance": f"{round(dist_km, 1)} km",
                "address": address,
                "phone": phone,
                "lat": s_lat,
                "lng": s_lon
            })
        
        # Pakkathula irukka shops first varanumnu sort pandrom
        shops.sort(key=lambda x: float(x['distance'].split()[0]))
        
        # Top 15 REAL shops mattum app-ku anupurom (No Demo Data)
        return {"shops": shops[:15]}
        
    except Exception as e:
        # Net cut aana empty list pogum, app-la proper ah "No shops found" nu azhaga varum
        return {"shops": []}