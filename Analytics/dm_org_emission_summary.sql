WITH BookingSource AS (
    SELECT 
        BF."ID" AS BookingFileID,
        O."ID" AS OrganizationId,
        BF."SystemReference" AS Trip,
        B."ID" AS BookingID,
        ASG."Departure" AS "Start Date",
        ASG."Arrival"  AS "End Date",
        AT."ID" AS TravelerId,
        AA."NameEN" AS Airline,
        ATA."NameEN" AS TripType,
        ACC."NameEN" AS Cabin_Class,
        AT."ETicketNumber" AS E_Ticket,
        B."RemitDate" as "RemitDate",

        CASE 
            WHEN B."AirTripTypeID" IN (0,1) THEN A."IATACode" || '-' || A1."IATACode"
            WHEN B."AirTripTypeID" = 4 THEN A."IATACode" || '-' || A1."IATACode" || '-*'
            ELSE NULL
        END AS Route,

        A."Latitude" AS LatFrom,
        A."Longitude" AS LonFrom,
        A1."Latitude" AS LatTo,
        A1."Longitude" AS LonTo,
        B."AirTripTypeID",
        ASG."BookedAirCabinClassID",

        CASE
            WHEN B."Amount" < 0 THEN 'Cancelled'
            WHEN B."IsDomestic" = TRUE AND B."Amount" < 100 THEN 'Changed'
            WHEN B."IsDomestic" = FALSE AND B."Amount" < 250 THEN 'Changed'
            ELSE B."BookingStatusID"::TEXT
        END AS Ticket_status

    FROM "CleanBooking" B
    INNER JOIN "CleanBookingFile" BF ON B."BookingFileID" = BF."ID"
    INNER JOIN "CleanAirTripType" ATA ON ATA."ID" = B."AirTripTypeID"
    INNER JOIN "CleanAirTraveler" AT ON AT."BookingID" = B."ID"
    LEFT JOIN "CleanOrganization" O ON BF."BookedForOrganizationID" = O."ID"
    INNER JOIN "CleanAirOriginDestination" AOD ON B."ID" = AOD."BookingID"
    INNER JOIN "CleanAirSegment" ASG ON AOD."ID" = ASG."AirOriginDestinationID"
    INNER JOIN "CleanAirCabinClass" ACC  ON ASG."BookedAirCabinClassID" = ACC."ID"
    INNER JOIN "CleanAirline" AA ON AA."ID" = ASG."MarketingAirlineID"
    INNER JOIN "CleanAirport" A  ON ASG."DepartureAirportID" = A."ID"
    INNER JOIN "CleanAirport" A1 ON ASG."ArrivalAirportID" = A1."ID"

    WHERE 
        B."TravelSectorID" = 1
        AND BF."BookingFileStatusID" = 16
        AND B."IsActive" = TRUE
        AND BF."BookedForOrganizationID" is not null
),

--------------------------------------------------------------------------------
-- BOOKING KM
--------------------------------------------------------------------------------
BookingKM AS (
    SELECT
        bs.*,
        CASE 
            WHEN bs.LatFrom IS NULL OR bs.LatTo IS NULL 
              OR bs.LonFrom IS NULL OR bs.LonTo IS NULL THEN 0
            ELSE 
                ACOS(
                    GREATEST(
                        LEAST(
                            SIN(bs.LatFrom*PI()/180)*SIN(bs.LatTo*PI()/180)
                            + COS(bs.LatFrom*PI()/180)*COS(bs.LatTo*PI()/180)
                            * COS((bs.LonTo-bs.LonFrom)*PI()/180),
                        1),
                    -1)
                ) * 6371 * CASE WHEN bs."AirTripTypeID" = 1 THEN 2 ELSE 1 END
        END AS KM
    FROM BookingSource bs
),

--------------------------------------------------------------------------------
-- SERVICE SOURCE (Using Flattened Columns)
--------------------------------------------------------------------------------
ServiceSource AS (
    SELECT 
        BF."ID" AS BookingFileID,
        O."ID" AS OrganizationId,
        BF."SystemReference" AS Trip,
        S."ID" AS BookingID,

        CAST(S."Service_Start_Date" AS DATE) AS "Start Date",
		CAST(S."Service_End_Date"   AS DATE) AS "End Date",

        ST."ID" AS TravelerId,

        -- Airline name extraction
        CASE 
            WHEN POSITION(' (' IN S."NameEN") > 0
            THEN SUBSTRING(S."NameEN" FROM 1 FOR POSITION(' (' IN S."NameEN") - 1)
            ELSE S."NameEN"
        END AS "Airline",

        S."Service" AS "TripType",

        -- Cabin class classification
        CASE
            WHEN S."ServiceTypeID" IN (13,15) 
                 AND LOWER(S."Service_Class") LIKE '%eco%' THEN 'Economy class'
            WHEN S."ServiceTypeID" IN (13,15) 
                 AND LOWER(S."Service_Class") LIKE '%busi%' THEN 'Business class'
            WHEN S."ServiceTypeID" IN (13,15) 
                 AND LOWER(S."Service_Class") LIKE '%first%' THEN 'First class'
            WHEN S."ServiceTypeID" IN (13,15) 
                 AND LOWER(S."Service_Class") LIKE '%premium%' THEN 'Premium economy class'
            ELSE 'Other'
        END AS "Cabin_Class",

        COALESCE(S."ProviderConfirmationReference", '-') AS "E_Ticket",
        S."RemitDate" as "RemitDate",

        COALESCE(S."Service_Location", '-') AS "Route",

        -- Extract IATA codes
        SPLIT_PART(S."Service_Location", '-', 1) AS "A0Code",
        SPLIT_PART(S."Service_Location", '-', 2) AS "A1Code",
        SPLIT_PART(S."Service_Location", '-', 3) AS "A2Code",
        SPLIT_PART(S."Service_Location", '-', 4) AS "A3Code",
        SPLIT_PART(S."Service_Location", '-', 5) AS "A4Code"
    FROM "CleanService" S
    INNER JOIN "CleanBookingFile" BF ON BF."ID" = S."BookingFileID"
    INNER JOIN "CleanOrganization" O ON O."ID" = BF."BookedForOrganizationID"
    INNER JOIN "CleanServiceTraveler" ST ON ST."ServiceID" = S."ID"
    WHERE
        S."ServiceTypeID" IN (13,15)
        AND BF."BookedForOrganizationID" is not null
        AND O."IsActive" = TRUE
        AND S."BookingStatusID" = 16
        AND S."IsActive" = TRUE
),
ServiceKM AS (
    SELECT
        ss.*,
        (
            COALESCE(
                ACOS(
                    SIN(A0."Latitude"*PI()/180)*SIN(A1."Latitude"*PI()/180) +
                    COS(A0."Latitude"*PI()/180)*COS(A1."Latitude"*PI()/180) *
                    COS((A1."Longitude"-A0."Longitude")*PI()/180)
                ) * 6371, 0)
          +
            COALESCE(
                ACOS(
                    SIN(A1."Latitude"*PI()/180)*SIN(A2."Latitude"*PI()/180) +
                    COS(A1."Latitude"*PI()/180)*COS(A2."Latitude"*PI()/180) *
                    COS((A2."Longitude"-A1."Longitude")*PI()/180)
                ) * 6371, 0)
          +
            COALESCE(
                ACOS(
                    SIN(A2."Latitude"*PI()/180)*SIN(A3."Latitude"*PI()/180) +
                    COS(A2."Latitude"*PI()/180)*COS(A3."Latitude"*PI()/180) *
                    COS((A3."Longitude"-A2."Longitude")*PI()/180)
                ) * 6371, 0)
          +
            COALESCE(
                ACOS(
                    SIN(A3."Latitude"*PI()/180)*SIN(A4."Latitude"*PI()/180) +
                    COS(A3."Latitude"*PI()/180)*COS(A4."Latitude"*PI()/180) *
                    COS((A4."Longitude"-A3."Longitude")*PI()/180)
                ) * 6371, 0)
        ) AS KM
    FROM ServiceSource ss
    LEFT JOIN "CleanAirport" A0 ON ss."A0Code" = A0."IATACode"
    LEFT JOIN "CleanAirport" A1 ON ss."A1Code" = A1."IATACode"
    LEFT JOIN "CleanAirport" A2 ON ss."A2Code" = A2."IATACode"
    LEFT JOIN "CleanAirport" A3 ON ss."A3Code" = A3."IATACode"
    LEFT JOIN "CleanAirport" A4 ON ss."A4Code" = A4."IATACode"
),
Unified AS (
    SELECT
        BookingFileID,'Booking' as booking_service_type, OrganizationId, Trip, BookingID, 
        "Start Date" AS Start_Date,
        "End Date" AS End_Date,
        TravelerId, Airline, TripType, Cabin_Class, 
        E_Ticket, "RemitDate", Route, KM
    FROM BookingKM
    UNION ALL
    SELECT
        BookingFileID,'Service' as booking_service_type, OrganizationId, Trip, BookingID, 
        "Start Date" AS Start_Date,
        "End Date" AS End_Date,
        TravelerId, "Airline", "TripType", "Cabin_Class", 
        "E_Ticket", "RemitDate", "Route", KM
    FROM ServiceKM
),
EmissionCalc AS (
    SELECT
        u.*,
        CASE
            WHEN u.KM <= 785 THEN u.KM * 1.09 * 0.16685
            WHEN u.KM > 785 AND u.KM <= 3700 THEN
                CASE WHEN LOWER(u.Cabin_Class) LIKE '%economy%' 
                     THEN u.KM * 1.09 * 0.09074
                     ELSE u.KM * 1.09 * 0.13612 END
            WHEN u.KM > 3700 THEN
                CASE WHEN LOWER(u.Cabin_Class) LIKE '%economy%' THEN u.KM * 1.09 * 0.07954
                     WHEN LOWER(u.Cabin_Class) LIKE '%first%'   THEN u.KM * 1.09 * 0.31816
                     ELSE u.KM * 1.09 * 0.23066 END
        END AS TotalEmission
    FROM Unified u
)
SELECT
    e.Trip as trip_id,
    e.BookingID as booking_service_id,
    e.booking_service_type as booking_service_type,
    e.OrganizationId as organization_id,
    e.TravelerId as traveler_id,
    e.TripType as trip_type,
    e.Airline as airline_name,
    e.Route as flight_route,
    e.Cabin_Class as booking_class,
    e.KM as distance,
    e.TotalEmission as emission,
    e.Start_Date as start_date,
    e.End_Date as end_date
FROM EmissionCalc e
ORDER BY e."RemitDate" DESC, e.OrganizationId;
