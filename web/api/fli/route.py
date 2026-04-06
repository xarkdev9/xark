# web/api/fli/route.py
# Vercel Python serverless function wrapping the fli library.
# Exposes flight search as POST /api/fli with JSON body.

import json
from typing import Any


async def handler(request) -> dict[str, Any]:
    """
    Vercel Python Function handler for flight search.
    Wraps the fli library and exposes flight search via POST /api/fli.
    """
    if request.method != "POST":
        return {
            "statusCode": 405,
            "body": json.dumps({"error": "Method not allowed"}),
            "headers": {"Content-Type": "application/json"},
        }

    try:
        body = await request.json() if request.body else {}

        origin = body.get("origin", "").upper()
        destination = body.get("destination", "").upper()
        date = body.get("date", "")
        cabin = body.get("cabin", "economy")
        max_results = body.get("max_results", 20)

        if not origin or not destination or not date:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "origin, destination, and date are required"}),
                "headers": {"Content-Type": "application/json"},
            }

        from fli.search import SearchFlights
        from fli.models import (
            FlightSearchFilters, FlightSegment, Airport, SeatType, PassengerInfo, MaxStops
        )

        # Resolve IATA codes to Airport enum
        try:
            origin_airport = Airport[origin]
            dest_airport = Airport[destination]
        except KeyError:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": f"Invalid airport code: {origin} or {destination}"}),
                "headers": {"Content-Type": "application/json"},
            }

        # Map cabin class
        seat_map = {
            "economy": SeatType.ECONOMY,
            "premium_economy": SeatType.PREMIUM_ECONOMY,
            "business": SeatType.BUSINESS,
            "first": SeatType.FIRST,
        }
        seat_type = seat_map.get(cabin.lower(), SeatType.ECONOMY)

        # Build filters
        filters = FlightSearchFilters(
            passenger_info=PassengerInfo(),
            flight_segments=[FlightSegment(
                departure_airport=[[origin_airport, 0]],
                arrival_airport=[[dest_airport, 0]],
                travel_date=date,
            )],
            seat_type=seat_type,
        )

        search = SearchFlights()
        results = search.search(filters)

        # Normalize results
        flights = []
        for r in results[:max_results]:
            legs = []
            for leg in r.legs:
                airline_code = ""
                try:
                    airline_code = leg.airline.name
                except Exception:
                    pass

                legs.append({
                    "airline": leg.airline.value,
                    "airline_code": airline_code,
                    "flight_number": leg.flight_number,
                    "departure_airport": leg.departure_airport.name,
                    "arrival_airport": leg.arrival_airport.name,
                    "departure_time": leg.departure_datetime.isoformat(),
                    "arrival_time": leg.arrival_datetime.isoformat(),
                    "duration": leg.duration,
                })

            first_leg = legs[0] if legs else {}
            flights.append({
                "price": r.price,
                "currency": r.currency or "USD",
                "duration": r.duration,
                "stops": r.stops,
                "airline_code": first_leg.get("airline_code", ""),
                "legs": legs,
            })

        return {
            "statusCode": 200,
            "body": json.dumps({
                "results": flights,
                "count": len(results),
                "returned": len(flights),
                "source": "fli",
            }),
            "headers": {"Content-Type": "application/json"},
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e), "source": "fli"}),
            "headers": {"Content-Type": "application/json"},
        }
