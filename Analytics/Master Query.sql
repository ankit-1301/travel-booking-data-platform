SELECT 
	 CASE
		WHEN 
[Booking].IsDomestic = 1 THEN 'Domestic'
		else 'International'
	End as 'Dom_INT'
,
	[BookingFile].SystemReference AS 'Musafir Ref', 
	CONCAT_WS('-',
	'B',
	[Booking].ID) AS 'ID',
	(CASE
		WHEN [BookingFile].MarketProfileID = 1 THEN 'UAE'
		WHEN [BookingFile].MarketProfileID = 2 THEN 'India'
		WHEN [BookingFile].MarketProfileID = 3 THEN 'Qatar'
		WHEN [BookingFile].MarketProfileID = 4 THEN 'Saudi Arabia'
	END) AS 'Market',
	[Organization].ID AS 'Organization ID',
	[Organization].[Name] AS 'Organization',
	CONCAT_WS(' ',
	[User].FirstName,
	[User].LastName) AS 'RM',
	(CASE
		WHEN [BookingFile].MarketProfileID = 1 THEN CONVERT(VARCHAR(50),
		TODATETIMEOFFSET([Booking].RemitDate, 4),
		103)
		WHEN [BookingFile].MarketProfileID = 2 THEN CONVERT(VARCHAR(50),
		TODATETIMEOFFSET([Booking].RemitDate, 5.5),
		103)
		WHEN [BookingFile].MarketProfileID = 3 THEN CONVERT(VARCHAR(50),
		TODATETIMEOFFSET([Booking].RemitDate, 3),
		103)
		WHEN [BookingFile].MarketProfileID = 4 THEN CONVERT(VARCHAR(50),
		TODATETIMEOFFSET([Booking].RemitDate, 3),
		103)
	END) AS 'Approved',
	 (CASE
		WHEN [Booking].TravelSectorID = 1 THEN 'Flight'
		WHEN [Booking].TravelSectorID = 3 THEN 'Hotel'
	END) AS 'Category', 
	COALESCE((CASE
		WHEN [Booking].TravelSectorID = 3 THEN [Booking].ProviderConfirmationReference
		ELSE [AirTraveler].ETicketNumber
	END),
	'-') AS 'E-ticket number',
	[BookingStatus].NameEN AS 'Ticket status',
	UPPER([BookingFile].CustomerFullName) AS 'For',
	(CASE
		WHEN [Booking].TravelSectorID = 1 THEN AirRouteInfo.[In]
		WHEN [Booking].TravelSectorID = 3 THEN HotelPropertyItem.NameEN
	END) AS 'In',
	(CASE
		WHEN [Booking].TravelSectorID = 1 THEN COALESCE(Airline.NameEN,
		'-')
		WHEN [Booking].TravelSectorID = 3 THEN COALESCE(HotelProperty.NameEN,
		'-')
	END) AS 'On/At',
	(CASE
		WHEN [Booking].TravelSectorID = 1 THEN AirRouteInfo.[Route]
		WHEN [Booking].TravelSectorID = 3 THEN [City].NameEN
	END) AS 'Route/City',
	(CASE
		WHEN [Booking].TravelSectorID = 1 THEN '-'
		WHEN [Booking].TravelSectorID = 3 THEN [Country].NameEN
	END) AS 'HotelCountry',
	(CASE
		WHEN [Booking].TravelSectorID = 1 THEN AirRouteInfo.[From]
		WHEN [Booking].TravelSectorID = 3 THEN CONVERT(VARCHAR(50),
		[Booking].CheckIn,
		103)
	END) AS 'From',
	(CASE
		WHEN [Booking].TravelSectorID = 1 THEN AirRouteInfo.[To]
		WHEN [Booking].TravelSectorID = 3 THEN CONVERT(VARCHAR(50),
		[Booking].CheckOut,
		103)
	END) AS 'To',
	 (CASE
		WHEN [Booking].TravelSectorID = 1 THEN AirRouteInfo.[Flight Time]
		WHEN [Booking].TravelSectorID = 3 THEN 0
	END) AS 'FlightTime',
	(CASE
		WHEN [Booking].TravelSectorID = 1
		AND [Booking].BookingStatusID IN (16, 20, 23)
				THEN ISNULL([AirTraveler].AmountNetRemit,
		0)
		ELSE ISNULL([Booking].AmountNetRemit,
		0)
	END) AS 'Amount',
	UPPER([Traveler].FullName) AS 'Estimated Traveler'
	---CONCAT(U1.FirstName,' ',U1.LastName) AS 'Travel coordinator'
	,
	COALESCE([Organization].OrganizationGroup,
	'-') AS 'Org Group'
FROM
	BookingFile
INNER JOIN Booking WITH (Nolock) ON
	[BookingFile].ID = [Booking].BookingFileID
INNER JOIN Organization WITH (Nolock) ON
	[BookingFile].BookedForOrganizationID = [Organization].ID
LEFT JOIN [User] WITH (Nolock) ON
	[Organization].RelationshipManagerUserID = [User].ID
	-----INNER JOIN aspnet_Membership AM ON AM.Email = BookingFile.Email
	----INNER JOIN [User] U1 ON U1.ID = AM.UserId
LEFT JOIN AirTraveler WITH (Nolock) ON
	[Booking].ID = [AirTraveler].BookingID
LEFT JOIN HotelTraveler WITH (Nolock) ON
	[Booking].ID = [HotelTraveler].BookingID
LEFT JOIN Traveler WITH (Nolock) ON
	[AirTraveler].TravelerID = [Traveler].ID
	OR [HotelTraveler].TravelerID = [Traveler].ID
LEFT JOIN TravelerProfile WITH (Nolock) ON
	[TravelerProfile].ID = [Traveler].TravelerProfileID
	AND [Organization].ID = TravelerProfile.OrganizationID
LEFT JOIN Airline WITH (Nolock) ON
	[Booking].ValidatingAirlineID = [Airline].ID
INNER JOIN BookingStatus WITH (Nolock) ON
	[BookingStatus].ID = [Booking].BookingStatusID
LEFT JOIN (
	SELECT
		[Booking].ID AS 'ID',
			CASE
			WHEN [Booking].AirTripTypeID = 1 
					  THEN SUM(DATEDIFF(MINUTE,
										DATEADD(HOUR, -[Cty1].UTCDifference, [AirSegment].Departure),
										DATEADD(HOUR, -[Cty2].UTCDifference, [AirSegment].Arrival)
										))/ 2
			-- Divide total time by 2 in case of round-trip flights
			ELSE SUM(DATEDIFF(MINUTE,
										DATEADD(HOUR, -[Cty1].UTCDifference, [AirSegment].Departure),
										DATEADD(HOUR, -[Cty2].UTCDifference, [AirSegment].Arrival)
										))
		END AS 'Flight Time',
			CONVERT(VARCHAR(50),
		MIN([AirSegment].Departure),
		103) AS 'From',
			CONVERT(VARCHAR(50),
		MAX([AirSegment].Arrival),
		103) AS 'To',
			MIN([AirCabinClass].NameEN) AS 'In',
			STRING_AGG(CONCAT_WS('-',
		[a1].IATACode,
		[a2].IATACode),
		', ') AS 'Route'
	FROM
		Booking
	INNER JOIN AirOriginDestination WITH (Nolock) ON
		[Booking].ID = [AirOriginDestination].BookingID
	INNER JOIN AirSegment WITH (Nolock) ON
		[AirSegment].AirOriginDestinationID = [AirOriginDestination].ID
	INNER JOIN AirCabinClass WITH (Nolock) ON
		[AirSegment].BookedAirCabinClassID = [AirCabinClass].ID
	INNER JOIN Airport A1 WITH (Nolock) ON
		[AirSegment].DepartureAirportID = a1.ID
	INNER JOIN City Cty1 WITH (Nolock) ON
		[A1].CityID = [Cty1].ID
	INNER JOIN Airport A2 WITH (Nolock) ON
		[AirSegment].ArrivalAirportID = a2.ID
	INNER JOIN City Cty2 WITH (Nolock) ON
		[A2].CityID = [Cty2].ID
	GROUP BY
		[Booking].ID,
		[Booking].AirTripTypeID 
				) AS AirRouteInfo ON
	[AirRouteInfo].ID = [Booking].ID
LEFT JOIN HotelPropertyItem WITH (Nolock) ON
	[Booking].HotelPropertyItemID = [HotelPropertyItem].ID
LEFT JOIN HotelProperty WITH (Nolock) ON
	[HotelProperty].ID = [HotelPropertyItem].HotelPropertyID
LEFT JOIN HotelRoomStay WITH (Nolock) ON
	[HotelRoomStay].BookingID = [Booking].ID
LEFT JOIN HotelRoomType WITH (Nolock) ON
	[HotelRoomType].ID = [HotelRoomStay].HotelRoomTypeID
LEFT JOIN Destination WITH (Nolock) ON
	[Destination].ID = [HotelProperty].DestinationID
LEFT JOIN CityDestination WITH (Nolock) ON
	[Destination].ID = [CityDestination].DestinationID
LEFT JOIN City WITH (Nolock) ON
	[CityDestination].CityID = [City].ID
LEFT JOIN Country WITH (Nolock) ON
	[Country].ID = [Destination].CountryID
WHERE
	[Booking].RemitDate between '2025-11-17 20:00:00' and '2025-12-17 20:00:00'
	AND [BookingFile].BookedForOrganizationID IS NOT NULL
	AND [BookingFile].MarketProfileID = 1
	AND [Booking].BookingStatusID > 0
	AND [Booking].IsActive = 1
	AND [Booking].RemitDate IS NOT NULL
	AND ([Organization].ID = 14688
		)
UNION
	SELECT 
	 case
		when 
	ServiceType.NameEN like '%DOM%' Then 'Domastic'
		When ServiceType.NameEN like '%INT%' Then 'International'
		else '-'
	end as 'Dom_INT' 
	,
	[BookingFile].SystemReference AS 'Musafir Ref', 
	CONCAT_WS('-',
	'S',
	[Service].ID) AS 'ID',
	(CASE
		WHEN [BookingFile].MarketProfileID = 1 THEN 'UAE'
		WHEN [BookingFile].MarketProfileID = 2 THEN 'India'
		WHEN [BookingFile].MarketProfileID = 3 THEN 'Qatar'
		WHEN [BookingFile].MarketProfileID = 4 THEN 'Saudi Arabia'
	END) AS 'Market',
	[Organization].ID AS 'Organization ID',
	[Organization].[Name] AS 'Organization',
	CONCAT_WS(' ',
	[User].FirstName,
	[User].LastName) AS 'RM',
	(CASE
		WHEN [BookingFile].MarketProfileID = 1 THEN CONVERT(VARCHAR(50),
		TODATETIMEOFFSET([Service].RemitDate, 4),
		103)
		WHEN [BookingFile].MarketProfileID = 2 THEN CONVERT(VARCHAR(50),
		TODATETIMEOFFSET([Service].RemitDate, 5.5),
		103)
		WHEN [BookingFile].MarketProfileID = 3 THEN CONVERT(VARCHAR(50),
		TODATETIMEOFFSET([Service].RemitDate, 3),
		103)
		WHEN [BookingFile].MarketProfileID = 4 THEN CONVERT(VARCHAR(50),
		TODATETIMEOFFSET([Service].RemitDate, 3),
		103)
	END) AS 'Approved',
	(CASE
		WHEN [Service].ServiceTypeID IN (13, 15) THEN 'Flight'
		WHEN [Service].ServiceTypeID IN (14, 20, 27, 31) THEN 'Hotel'
		ELSE [ServiceType].NameEN
	END) AS 'Category',
	COALESCE([Service].ProviderConfirmationReference,
	'-') AS 'E-ticket number',
	[BookingStatus].NameEN AS 'Ticket status',
	[BookingFile].CustomerFullName AS 'For',
	/* Effort to clean data for Air cabin class and Hotel room types */
	(CASE
		
WHEN [Service].ServiceTypeID IN (14, 20, 27, 31)
AND 
			   [Service].Details.value('(/ServiceDetailsInfo/@SC)[1]',
			'VARCHAR(50)') LIKE '%STAND%' THEN 'Standard room'
WHEN [Service].ServiceTypeID IN (14, 20, 27, 31)
AND 
			   [Service].Details.value('(/ServiceDetailsInfo/@SC)[1]',
				'VARCHAR(50)') LIKE '%PREMI%' THEN 'Deluxe room'
WHEN [Service].ServiceTypeID IN (14, 20, 27, 31)
AND 
			   [Service].Details.value('(/ServiceDetailsInfo/@SC)[1]',
					'VARCHAR(50)') LIKE '%exec%' THEN 'Executive room'
WHEN [Service].ServiceTypeID IN (14, 20, 27, 31)
AND
			   [Service].Details.value('(/ServiceDetailsInfo/@SC)[1]',
						'VARCHAR(50)') LIKE '%lux%' THEN 'Deluxe room'
WHEN [Service].ServiceTypeID IN (14, 20, 27, 31)
AND
			   [Service].Details.value('(/ServiceDetailsInfo/@SC)[1]',
							'VARCHAR(50)') LIKE '%ECO%' THEN 'Standard room'
WHEN [Service].ServiceTypeID IN (13, 15)
AND
			   [Service].Details.value('(/ServiceDetailsInfo/@SC)[1]',
								'VARCHAR(50)') LIKE '%STAND%' THEN 'Economy class'
WHEN [Service].ServiceTypeID IN (13, 15)
AND
			   [Service].Details.value('(/ServiceDetailsInfo/@SC)[1]',
									'VARCHAR(50)') LIKE '%eco%' THEN 'Economy class'
WHEN [Service].ServiceTypeID IN (13, 15)
AND
			   [Service].Details.value('(/ServiceDetailsInfo/@SC)[1]',
										'VARCHAR(50)') LIKE '%Busi%' THEN 'Business class'
WHEN [Service].ServiceTypeID IN (13, 15)
AND
			   [Service].Details.value('(/ServiceDetailsInfo/@SC)[1]',
											'VARCHAR(50)') LIKE '%First%' THEN 'First class'
WHEN [Service].ServiceTypeID IN (13, 15)
AND
			   [Service].Details.value('(/ServiceDetailsInfo/@SC)[1]',
												'VARCHAR(50)') LIKE '%PREMIUM%' THEN 'Premium economy class'
ELSE
		       'Other'
END) AS 'In',
	(CASE
		WHEN [Service].ServiceTypeID IN (13, 15) 
	      THEN COALESCE (
			   TRIM(LEFT([Service].Details.value('(/ServiceDetailsInfo/SN)[1]', 'varchar(max)'), 
					PATINDEX('% (%', [Service].Details.value('(/ServiceDetailsInfo/SN)[1]', 'varchar(max)')))), 
						'-')
		WHEN [Service].ServiceTypeID IN (14, 20, 27, 31)
	      THEN TRIM([Service].Details.value('(/ServiceDetailsInfo/SN)[1]', 'varchar(max)'))
		ELSE '-'
	END) AS 'On/At',
	COALESCE([Service].Details.value('(/ServiceDetailsInfo/IL/@LOC)[1]',
	'VARCHAR(50)'),
	'-') AS 'Route/City',
	COALESCE(CountryInfo.[Country],
	'-') AS 'HotelCountry',
	-- convert yyyy-mm-dd to dd/mm/yyyy (this new format is a result of Navision process hardening)
	(CASE
		WHEN [Service].Details.exist('/ServiceDetailsInfo/IL/@SD') = 1
			AND [Service].Details.value('(/ServiceDetailsInfo/IL/@SD)[1]',
			'varchar(20)') like '____-%'
	THEN 
		CONCAT(RIGHT([Service].Details.value('(/ServiceDetailsInfo/IL/@SD)[1]', 'varchar(20)'), 2), 
       '/',
	   SUBSTRING([Service].Details.value('(/ServiceDetailsInfo/IL/@SD)[1]', 'varchar(20)'), 
			PATINDEX('%-%', [Service].Details.value('(/ServiceDetailsInfo/IL/@SD)[1]', 'varchar(20)'))+ 1,
			2),
	   '/',
	   LEFT([Service].Details.value('(/ServiceDetailsInfo/IL/@SD)[1]', 'varchar(20)'), 4))
			-- Checks for attribute /@ED and then replaces date format /YY to /YYYY;
			-- if attribute not found in Service (like Visa), then inserts dummy value of [Service].RemitDate */
			WHEN [Service].Details.exist('/ServiceDetailsInfo/IL/@SD') = 1
		  THEN
				REPLACE ([Service].Details.value('(/ServiceDetailsInfo/IL/@SD)[1]',
			'VARCHAR(50)'),
			/* Input String */
						 RIGHT([Service].Details.value('(/ServiceDetailsInfo/IL/@SD)[1]',
			'VARCHAR(50)'),
			3),
			/* Substring */
			REPLACE(RIGHT([Service].Details.value('(/ServiceDetailsInfo/IL/@SD)[1]', 'VARCHAR(50)'), 3), /* Replace '/' by '/20' */
								 '/',
								 '/20')
						)
			ELSE
				CONVERT(VARCHAR(50),
			[Service].RemitDate,
			103)
		END) AS 'From',
	-- convert yyyy-mm-dd to dd/mm/yyyy (this new format is a result of Navision process hardening)
	(CASE
		WHEN [Service].Details.exist('/ServiceDetailsInfo/IL/@ED') = 1
			AND [Service].Details.value('(/ServiceDetailsInfo/IL/@ED)[1]',
			'varchar(20)') like '____-%'
	THEN 
		CONCAT(RIGHT([Service].Details.value('(/ServiceDetailsInfo/IL/@ED)[1]', 'varchar(20)'), 2), 
       '/',
	   SUBSTRING([Service].Details.value('(/ServiceDetailsInfo/IL/@ED)[1]', 'varchar(20)'), 
			PATINDEX('%-%', [Service].Details.value('(/ServiceDetailsInfo/IL/@ED)[1]', 'varchar(20)'))+ 1,
			2),
	   '/',
	   LEFT([Service].Details.value('(/ServiceDetailsInfo/IL/@ED)[1]', 'varchar(20)'), 4))
			-- Checks for attribute /@ED and then replaces date format /YY to /YYYY;
			-- if attribute not found in Service (like Visa), then inserts dummy value of [Service].RemitDate */
			WHEN [Service].Details.exist('/ServiceDetailsInfo/IL/@ED') = 1
		  THEN
				REPLACE ([Service].Details.value('(/ServiceDetailsInfo/IL/@ED)[1]',
			'VARCHAR(50)'),
			/* Input String */
						 RIGHT([Service].Details.value('(/ServiceDetailsInfo/IL/@ED)[1]',
			'VARCHAR(50)'),
			3),
			/* Substring */
			REPLACE(RIGHT([Service].Details.value('(/ServiceDetailsInfo/IL/@ED)[1]', 'VARCHAR(50)'), 3), /* Replace '/' by '/20' */
								 '/',
								 '/20')
						)
			ELSE
				CONVERT(VARCHAR(50),
			[Service].RemitDate,
			103)
		END) AS 'To',
	0 AS 'FlightTime',
	ISNULL([Service].AmountNetRemit,
	0) AS 'Amount',
	COALESCE(UPPER([Traveler].FullName),
	'-') AS 'Estimated Traveler'
	-----CONCAT(U1.FirstName,' ',U1.LastName) AS 'Travel coordinator'
	,
	COALESCE([Organization].OrganizationGroup,
	'-') AS 'Org Group'
FROM
	BookingFile
INNER JOIN [Service] WITH (Nolock) ON
	[BookingFile].ID = [Service].BookingFileID
INNER JOIN Organization WITH (Nolock) ON
	[BookingFile].BookedForOrganizationID = [Organization].ID
LEFT JOIN [User] WITH (Nolock) ON
	[Organization].RelationshipManagerUserID = [User].ID
	-----INNER JOIN aspnet_Membership AM ON AM.Email = BookingFile.Email
	-----INNER JOIN [User] U1 ON U1.ID = AM.UserId
LEFT JOIN ServiceTraveler WITH (Nolock) ON
	[Service].ID = [ServiceTraveler].ServiceID
LEFT JOIN Traveler WITH (Nolock) ON
	[ServiceTraveler].TravelerID = [Traveler].ID
LEFT JOIN TravelerProfile WITH (Nolock) ON
	[TravelerProfile].ID = [Traveler].TravelerProfileID
	AND [Organization].ID = TravelerProfile.OrganizationID
INNER JOIN BookingStatus WITH (Nolock) ON
	[BookingStatus].ID = [Service].BookingStatusID
LEFT JOIN ServiceType WITH (Nolock) ON
	[Service].ServiceTypeID = [ServiceType].ID
LEFT JOIN 
			(/* Retrieve Country details from Hotels added as Service */
	SELECT
		[W].ServiceID AS 'ID',
		[Country].NameEN AS 'Country'
	FROM 
				(
		SELECT
			[Service].ID AS 'ServiceID',
				UPPER(RIGHT(SUBSTRING([Service].Details.value('(/ServiceDetailsInfo/IL/@LOC)[1]', 'varchar(50)'),
							PATINDEX('%(%', [Service].Details.value('(/ServiceDetailsInfo/IL/@LOC)[1]', 'varchar(50)')),
									4), 3)) AS 'CityIATA'
		FROM
			[Service]
		WHERE
			ServiceTypeID IN (14, 20, 27, 31)
				) AS W
	INNER JOIN City ON
		[City].IATACode = [W].CityIATA
	INNER JOIN Country ON
		[Country].ID = [City].CountryID
			) AS CountryInfo ON
	[Service].ID = [CountryInfo].ID
WHERE
	[Service].RemitDate between '2025-11-17 20:00:00' and '2025-12-17 20:00:00'
	AND [BookingFile].BookedForOrganizationID IS NOT NULL
	AND [BookingFile].MarketProfileID = 1
	AND [Service].BookingStatusID > 0
	AND [Service].IsActive = 1
	AND [Service].RemitDate IS NOT NULL
	AND ([Organization].ID = 14688
		)
