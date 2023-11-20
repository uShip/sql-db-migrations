
/****** Object:  StoredProcedure [IHD].[Pricing_Engine_Proc]    Script Date: 11/17/2023 3:56:22 PM ******/

CREATE OR ALTER proc [dbo].[Pricing_Engine_Proc] as

/*****************************************************************************************************************/

--SET VARIABLES

declare	@startdate as date,
	@enddate as date,
	@int as int,
	@numeric as float,
	@text as nvarchar(100),
	@keyword as nvarchar(100),
	@difficulty_idx as float,
	@fragile_idx as float,
	@singleitemqty as float,
	@addtl_percent as float

set	@startdate = '4/01/23'    -- set start date
set	@enddate = '10/16/23'      -- set end date
set	@numeric = 0
set	@int = 0
set	@difficulty_idx = 0
set	@fragile_idx = 0
set	@singleitemqty = 0
set	@addtl_percent = 0



/*****************************************************************************************************************/

--  Build #items table with total count of items * unitcount

drop table	#items
select	l.packageid,
	sum(cast(i.unitcount as float)) 'Qty'
into	#items
from	reporting.dataset.listing l
join	reporting.dataset.bids b
		on l.packageid = b.packageid
		and b.netmatch > 0
join	reporting.dataset.items i
		on l.packageid = i.packageid
where	l.origincountryid = 1
	and l.destinationcountryid = 1
	and not (l.originstate = 'alaska' and l.destinationstate = 'alaska')
	and l.category = 'household goods'
	and l.nm > 0
	--and b.dateaccepted >= @startdate
	--and b.dateaccepted < @enddate
group by	l.packageid



/*****************************************************************************************************************/


-- Get Fuel Prices from two weeks ago by week

drop table	#fuelprices
select	c.week_end_date,
	fp.gas
into	#fuelprices
from	reporting.dbo.calendar c
join	pricingreferencetables.dbo.fuelprices fp                                 --this table gets created every day from proc sra.fuelprices.get_fuelprices_from_snowflake
		on c.day_date = fp.date
where	c.day_date >= '01/01/17'
	and c.week_end_date < cast(getdate() as date)
order by	1


/*****************************************************************************************************************/

--  Establish input data (historical) to check model against

drop table	#predictions_output
select	getdate() 'RunDate',
	l.packageid,
	l.datecreated,
	l.title,
	@text 'OMSA',
	@text 'DMSA',
	@int 'OMSA_miles',
	@int 'DMSA_miles',
	@numeric 'PPM',
	l.origincity,
	l.originstate,
	sa1.stateabbr 'OriginST',
	l.originzip,
	l.destinationcity,
	l.destinationstate,
	sa2.stateabbr 'DestinationST',
	l.destinationzip,
	l.mileage,
	l.TimeFrameLatestPickup 'LISTING_Latest_pickup',
	l.timeframelatestdelivery 'LISTING_Latest_delivery',
	l.totalweight,
	l.items 'TotalItems',
	i.qty 'TotalQty',
	l.bids,
	isnull(cast(i1.Unitcount as int),0) 'Item1Qty',
	isnull(cast(i2.Unitcount as int),0) 'Item2Qty',
	isnull(cast(i3.Unitcount as int),0) 'Item3Qty',
	isnull(cast(i4.Unitcount as int),0) 'Item4Qty',
	isnull(cast(i5.Unitcount as int),0) 'Item5Qty',
	i1.title 'Item1Title',
	i2.title 'Item2Title',
	i3.title 'Item3Title',
	i4.title 'Item4Title',
	i5.title 'Item5Title',
	cast(i1.length as float) 'Item1Length',
	cast(i1.height as float) 'Item1Height',
	cast(i1.width as float) 'Item1Width',
	cast(i1.weight as float) 'Item1Weight',
	cast(i1.length as float)*cast(i1.height as float)*cast(i1.width as float) 'Item1Volume',
	cast(i2.length as float) 'Item2Length',
	cast(i2.height as float) 'Item2Height',
	cast(i2.width as float) 'Item2Width',
	cast(i2.weight as float) 'Item2Weight',
	cast(i2.length as float)*cast(i2.height as float)*cast(i2.width as float) 'Item2Volume',
	cast(i3.length as float) 'Item3Length',
	cast(i3.height as float) 'Item3Height',
	cast(i3.width as float) 'Item3Width',
	cast(i3.weight as float) 'Item3Weight',
	cast(i3.length as float)*cast(i3.height as float)*cast(i3.width as float) 'Item3Volume',
	cast(i4.length as float) 'Item4Length',
	cast(i4.height as float) 'Item4Height',
	cast(i4.width as float) 'Item4Width',
	cast(i4.weight as float) 'Item4Weight',
	cast(i4.length as float)*cast(i4.height as float)*cast(i4.width as float) 'Item4Volume',
	cast(i5.length as float) 'Item5Length',
	cast(i5.height as float) 'Item5Height',
	cast(i5.width as float) 'Item5Width',
	cast(i5.weight as float) 'Item5Weight',
	cast(i5.length as float)*cast(i5.height as float)*cast(i5.width as float) 'Item5Volume',
	cast(i1.unitcount as float)*cast(i1.length as float)*cast(i1.height as float)*cast(i1.width as float) 'Item1TotalVolume',
	cast(i2.unitcount as float)*cast(i2.length as float)*cast(i2.height as float)*cast(i2.width as float) 'Item2TotalVolume',
	cast(i3.unitcount as float)*cast(i3.length as float)*cast(i3.height as float)*cast(i3.width as float) 'Item3TotalVolume',
	cast(i4.unitcount as float)*cast(i4.length as float)*cast(i4.height as float)*cast(i4.width as float) 'Item4TotalVolume',
	cast(i5.unitcount as float)*cast(i5.length as float)*cast(i5.height as float)*cast(i5.width as float) 'Item5TotalVolume',
	cast(i1.unitcount as float)*cast(i1.weight as float) 'Item1TotalWeight',
	cast(i2.unitcount as float)*cast(i2.weight as float) 'Item2TotalWeight',
	cast(i3.unitcount as float)*cast(i3.weight as float) 'Item3TotalWeight',
	cast(i4.unitcount as float)*cast(i4.weight as float) 'Item4TotalWeight',
	cast(i5.unitcount as float)*cast(i5.weight as float) 'Item5TotalWeight',
	cast(l.nypchanges as int) 'NYPChanges',
	@text 'Titlekeyword',
	@text 'Item1keyword',
	@text 'Item2keyword',
	@text 'Item3keyword',
	@text 'Item4keyword',
	@text 'Item5keyword',
	@numeric 'TitleDiff',
	@numeric 'Item1Diff',
	@numeric 'Item2Diff',
	@numeric 'Item3Diff',
	@numeric 'Item4Diff',
	@numeric 'Item5Diff',
	@numeric 'TitleFrag',
	@numeric 'Item1Frag',
	@numeric 'Item2Frag',
	@numeric 'Item3Frag',
	@numeric 'Item4Frag',
	@numeric 'Item5Frag',
	case	when l.totalweight > 400 then 2
		when l.totalweight > 200 or (i1.length > '84' or i1.height > '84' or i1.width > '84') then 1
		else 0 end 'BB',
               u.username 'Carrier',
	b.dateaccepted 'DateAccepted',
	b.bidvolumeusd 'MatchPrice',
	b.bidvolumeusd-isnull(r.nmr_post,0) 'Amount_To_Carrier',
               l.forecastsegment 'Partner',
               case	when l.gm > 1 then 1 else 0 end 'Rematched',
               l.originalnypamount 'Posted_At',
               y.rate_table_nyp_amount 'Old_Prediction',
               fp.gas 'Gas_2wa',
               'ServiceLevel' =	@int,
               'HighValue'	=	case	when l.title like '%hv%' then 1 else 0 end,
	'Multi_item'	=	l.items,
	'Zipcode_Tier' =	case	when zta.dtier is not null then zta.dtier else '' end,
	'Difficulty_idx' = @int,
	@numeric 'Base_Rate',
	'FixedCost' = 0,
               @numeric 'Fuel_Surcharge',
	@numeric 'Zipcode_Tier_Surcharge',
               @numeric 'ServiceLevel_Surcharge',
               @numeric 'StateO_Surcharge',
               @numeric 'StateD_Surcharge',
	@numeric 'State_Route_Surcharge',
               @numeric 'CongestedO_Surcharge',
               @numeric 'CongestedD_Surcharge',
	@numeric 'OMSA_Surcharge',
	@numeric 'DMSA_Surcharge',
	@numeric 'Weight_Surcharge',
               @numeric 'BB_Surcharge',
	@numeric 'Difficulty_Surcharge',
	@numeric 'Mileage_Surcharge',
	@numeric 'Multi_item_Surcharge',
               @numeric 'Expedited_PU_Surcharge',
               @numeric 'Expedited_DEL_Surcharge',
	@numeric 'Close_to_OMSA_Surcharge',
	@numeric 'Close_to_DMSA_Surcharge',
	@numeric 'Addtl_qty_surcharge',
	@numeric 'TooHigh',
	@numeric 'TooLow',
	@numeric 'Good',
               l.originalnypamount 'Posted_Amt',
               y.rate_table_nyp_amount 'Old_Prediction2',
	b.bidvolumeusd 'Match_Price',
	'Match_price_Out_of_Range' = case	when	((l.mileage > 250 and l.mileage <= 500 and (b.bidvolumeusd/l.mileage < .534 or b.bidvolumeusd/l.mileage > 1.14))
				or
				(l.mileage > 500 and  l.mileage <= 1000 and (b.bidvolumeusd/l.mileage < .32 or b.bidvolumeusd/l.mileage > .685))
				or
				(l.mileage > 1000 and  l.mileage <= 1500 and (b.bidvolumeusd/l.mileage < .237 or b.bidvolumeusd/l.mileage > .41))
				or
				(l.mileage > 1500 and l.mileage  <= 2000 and (b.bidvolumeusd/l.mileage < .193 or b.bidvolumeusd/l.mileage > .356))
				or
				(l.mileage > 2000 and  l.mileage <= 2500 and (b.bidvolumeusd/l.mileage < .168 or b.bidvolumeusd/l.mileage > .295))
				or
				(l.mileage > 2500 and  l.mileage <= 3000 and (b.bidvolumeusd/l.mileage < .14 or b.bidvolumeusd/l.mileage > .24))
				or
				(l.mileage > 3000  and (b.bidvolumeusd/l.mileage < .136 or b.bidvolumeusd/l.mileage > .258))) then 1 else 0 end,
	@numeric 'Rate_Engine_prediction'
into	#predictions_output
from	reporting.dataset.listing l
join	reporting.dataset.bids b
		on l.packageid = b.packageid
		and b.netmatch > 0
left join	reporting.dataset.items i1
		on l.packageid = i1.packageid
		and i1.rank = 1
left join	reporting.dataset.items i2
		on l.packageid = i2.packageid
		and i2.rank = 2
left join	reporting.dataset.items i3
		on l.packageid = i3.packageid
		and i3.rank = 3
left join	reporting.dataset.items i4
		on l.packageid = i4.packageid
		and i4.rank = 4
left join	reporting.dataset.items i5
		on l.packageid = i5.packageid
		and i5.rank = 5
left join	#items i
		on i.packageid = l.packageid
join	reporting.dataset.tracking t
		on b.packagematchid = t.packagematchid
join	reporting.dataset.revenue r
		on b.packagematchid = r.packagematchid
left join	pricingreferencetables.dbo.stateabb sa1
		on l.originstate = sa1.state
left join	pricingreferencetables.dbo.stateabb sa2
		on l.destinationstate = sa2.state
Join	reporting.dataset.users u
                              on b.userid = u.userid
join	pricingreferencetables.dbo.InHomeDelivery_RateTable_Comparison y
		on l.packageid = y.packageid
left join	pricingreferencetables.dbo.servicelevel_v6 sl
		on l.forecastsegment = sl.partner
left join	pricingreferencetables.dbo.prediction_adjustment_v6 pa
		on 1 = 1
left join	pricingreferencetables.dbo.zipcode_tier_assignments zta
		on substring(l.destinationzip,1,5) = zta.zip
left join	pricingreferencetables.dbo.zipcode_tiers_4_v6 zt
		on zta.dtier = zt.tier
join	reporting.dbo.calendar c
		on c.day_date = l.d_datecreated
left join	#fuelprices fp
		on fp.week_end_date = dateadd(dd,-14,c.week_end_date)
where
l.forecastsegment = 'Chairish'
 and not (l.originstate = 'alaska' and l.destinationstate = 'alaska')
	and not l.title like '%*comp%'
	and cast(t.delivereddate as date) >= @startdate
	and cast(t.delivereddate as date) <= @enddate
	and cast(l.datecreated as date) >= @startdate



	--select datecreated,gas_2wa from #predictions_output order by datecreated







/*********************************************************/

-- breakout keywords from listing titles and assign a difficulty index
--Cursorfetch: The number of variables declared in the INTO list must match that of selected columns.

DECLARE	IHDIDX CURSOR
FOR	select keyword,difficulty_idx,fragile_idx,singleitemqty,addtl_percent from pricingreferencetables.dbo.furniture_indexes

OPEN	IHDIDX
FETCH NEXT
FROM	IHDIDX INTO @keyword,@difficulty_idx,@fragile_idx,@singleitemqty,@addtl_percent

WHILE	@@FETCH_STATUS = 0
    BEGIN


	update	#predictions_output
	set	titlediff = case when x.titlediff < @difficulty_idx then @difficulty_idx else x.titlediff end,
		titlefrag = case when x.titlefrag < @fragile_idx then @fragile_idx else x.titlefrag end,
		titlekeyword = case when x.titlekeyword > '' and x.titlekeyword <> @keyword then x.titlekeyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.title),0) > 0

	update	#predictions_output
	set	item1diff = case when x.item1diff < @difficulty_idx then @difficulty_idx else x.item1diff end,
		item1frag = case when x.item1frag < @fragile_idx then @fragile_idx else x.item1frag end,
		item1keyword = case when item1keyword > '' and x.item1keyword <> @keyword  then item1keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item1title),0) > 0


	update	#predictions_output
	set	item2diff = case when x.item2diff < @difficulty_idx then @difficulty_idx else x.item2diff end,
		item2frag = case when x.item2frag < @fragile_idx then @fragile_idx else x.item2frag end,
		item2keyword = case when item2keyword > '' and x.item2keyword <> @keyword  then item2keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item2title),0) > 0
		and x.totalitems >= 2


	update	#predictions_output
	set	item3diff = case when x.item3diff < @difficulty_idx then @difficulty_idx else x.item3diff end,
		item3frag = case when x.item3frag < @fragile_idx then @fragile_idx else x.item3frag end,
		item3keyword = case when item3keyword > ''  and x.item3keyword <> @keyword  then item3keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item3title),0) > 0
		and x.totalitems >= 3


	update	#predictions_output
	set	item4diff = case when x.item4diff < @difficulty_idx then @difficulty_idx else x.item4diff end,
		item4frag = case when x.item4frag < @fragile_idx then @fragile_idx else x.item4frag end,
		item4keyword = case when item4keyword > ''  and x.item4keyword <> @keyword then item4keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item4title),0) > 0
		and x.totalitems >= 4


	update	#predictions_output
	set	item5diff = case when x.item5diff < @difficulty_idx then @difficulty_idx else x.item5diff end,
		item5frag = case when x.item5frag < @fragile_idx then @fragile_idx else x.item5frag end,
		item5keyword = case when item5keyword > ''  and x.item5keyword <> @keyword then item5keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item5title),0) > 0
		and x.totalitems >= 5

	update	#predictions_output
	set	titlediff = case when x.titlediff < @difficulty_idx then @difficulty_idx else x.titlediff end,
		titlefrag = case when x.titlefrag < @fragile_idx then @fragile_idx else x.titlefrag end,
		titlekeyword = case when x.titlekeyword > '' and x.titlekeyword <> @keyword then x.titlekeyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.title),0) > 0

	update	#predictions_output
	set	item1diff = case when x.item1diff < @difficulty_idx then @difficulty_idx else x.item1diff end,
		item1frag = case when x.item1frag < @fragile_idx then @fragile_idx else x.item1frag end,
		item1keyword = case when item1keyword > '' and x.item1keyword <> @keyword  then item1keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item1title),0) > 0


	update	#predictions_output
	set	item2diff = case when x.item2diff < @difficulty_idx then @difficulty_idx else x.item2diff end,
		item2frag = case when x.item2frag < @fragile_idx then @fragile_idx else x.item2frag end,
		item2keyword = case when item2keyword > '' and x.item2keyword <> @keyword  then item2keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item2title),0) > 0
		and x.totalitems >= 2


	update	#predictions_output
	set	item3diff = case when x.item3diff < @difficulty_idx then @difficulty_idx else x.item3diff end,
		item3frag = case when x.item3frag < @fragile_idx then @fragile_idx else x.item3frag end,
		item3keyword = case when item3keyword > ''  and x.item3keyword <> @keyword  then item3keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item3title),0) > 0
		and x.totalitems >= 3


	update	#predictions_output
	set	item4diff = case when x.item4diff < @difficulty_idx then @difficulty_idx else x.item4diff end,
		item4frag = case when x.item4frag < @fragile_idx then @fragile_idx else x.item4frag end,
		item4keyword = case when item4keyword > ''  and x.item4keyword <> @keyword then item4keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item4title),0) > 0
		and x.totalitems >= 4


	update	#predictions_output
	set	item5diff = case when x.item5diff < @difficulty_idx then @difficulty_idx else x.item5diff end,
		item5frag = case when x.item5frag < @fragile_idx then @fragile_idx else x.item5frag end,
		item5keyword = case when item5keyword > ''  and x.item5keyword <> @keyword then item5keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item5title),0) > 0
		and x.totalitems >= 5

	update	#predictions_output
	set	titlediff = case when x.titlediff < @difficulty_idx then @difficulty_idx else x.titlediff end,
		titlefrag = case when x.titlefrag < @fragile_idx then @fragile_idx else x.titlefrag end,
		titlekeyword = case when x.titlekeyword > '' and x.titlekeyword <> @keyword then x.titlekeyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.title),0) > 0

	update	#predictions_output
	set	item1diff = case when x.item1diff < @difficulty_idx then @difficulty_idx else x.item1diff end,
		item1frag = case when x.item1frag < @fragile_idx then @fragile_idx else x.item1frag end,
		item1keyword = case when item1keyword > '' and x.item1keyword <> @keyword  then item1keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item1title),0) > 0


	update	#predictions_output
	set	item2diff = case when x.item2diff < @difficulty_idx then @difficulty_idx else x.item2diff end,
		item2frag = case when x.item2frag < @fragile_idx then @fragile_idx else x.item2frag end,
		item2keyword = case when item2keyword > '' and x.item2keyword <> @keyword  then item2keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item2title),0) > 0
		and x.totalitems >= 2


	update	#predictions_output
	set	item3diff = case when x.item3diff < @difficulty_idx then @difficulty_idx else x.item3diff end,
		item3frag = case when x.item3frag < @fragile_idx then @fragile_idx else x.item3frag end,
		item3keyword = case when item3keyword > ''  and x.item3keyword <> @keyword  then item3keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item3title),0) > 0
		and x.totalitems >= 3


	update	#predictions_output
	set	item4diff = case when x.item4diff < @difficulty_idx then @difficulty_idx else x.item4diff end,
		item4frag = case when x.item4frag < @fragile_idx then @fragile_idx else x.item4frag end,
		item4keyword = case when item4keyword > ''  and x.item4keyword <> @keyword then item4keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item4title),0) > 0
		and x.totalitems >= 4


	update	#predictions_output
	set	item5diff = case when x.item5diff < @difficulty_idx then @difficulty_idx else x.item5diff end,
		item5frag = case when x.item5frag < @fragile_idx then @fragile_idx else x.item5frag end,
		item5keyword = case when item5keyword > ''  and x.item5keyword <> @keyword then item5keyword+' / '+@keyword else @keyword end
               from	#predictions_output x
	where	isnull(charindex(@keyword,x.item5title),0) > 0
		and x.totalitems >= 5

        FETCH NEXT FROM IHDIDX INTO @keyword,@difficulty_idx,@fragile_idx,@singleitemqty,@addtl_percent
    END


close	IHDIDX

DEALLOCATE	IHDIDX


update	#predictions_output
set	difficulty_idx = titlediff

update	#predictions_output
set	difficulty_idx = item1diff
where	item1diff > difficulty_idx


update	#predictions_output
set	difficulty_idx = item2diff
where	item2diff > difficulty_idx


update	#predictions_output
set	difficulty_idx = item3diff
where	item3diff > difficulty_idx


update	#predictions_output
set	difficulty_idx = item4diff
where	item4diff > difficulty_idx


update	#predictions_output
set	difficulty_idx = item5diff
where	item5diff > difficulty_idx


update	#predictions_output
set	item2diff = 0,
	item2frag = 0
from	#predictions_output x
where	x.totalitems < 2


update	#predictions_output
set	item3diff = 0,
	item3frag = 0
from	#predictions_output x
where	x.totalitems < 3

update	#predictions_output
set	item4diff = 0,
	item4frag = 0
from	#predictions_output x
where	x.totalitems < 4

update	#predictions_output
set	item5diff = 0,
	item5frag = 0
from	#predictions_output x
where	x.totalitems < 5


update	#predictions_output
set	difficulty_idx = titlediff

update	#predictions_output
set	difficulty_idx = item1diff
where	item1diff > difficulty_idx


update	#predictions_output
set	difficulty_idx = item2diff
where	item2diff > difficulty_idx


update	#predictions_output
set	difficulty_idx = item3diff
where	item3diff > difficulty_idx


update	#predictions_output
set	difficulty_idx = item4diff
where	item4diff > difficulty_idx


update	#predictions_output
set	difficulty_idx = item5diff
where	item5diff > difficulty_idx

--select	*
--from	#predictions_output order by 2


/***********************************************************************************/

/*****************************************************************************************************************/

-- Get origin MSA (or closest MSA and provide miles from MSA to origin)

update	#predictions_output
set	omsa = case when zco.msa_name > '' then zco.msa_name else mo.msa_name end,
	omsa_miles = case when zco.msa_name > '' then 0 else mo.distance end
from	#predictions_output po
left join	pricingreferencetables.dbo.zipcodes zco
		on substring(po.originzip,1,5) = zco.zipcode
		and zco.primaryrecord = 'P'
left join	pricingreferencetables.dbo.zips_with_closest_msa mo
		on substring(po.originzip,1,5) = mo.zipcode



/*****************************************************************************************************************/

-- Get destination MSA (or closest MSA and provide miles from MSA to destination)


update	#predictions_output
set	dmsa = case when zcd.msa_name > '' then zcd.msa_name else md.msa_name end,
	dmsa_miles = case when zcd.msa_name > '' then 0 else md.distance end
from	#predictions_output po
left join	pricingreferencetables.dbo.zipcodes zcd
		on substring(po.destinationzip,1,5) = zcd.zipcode
		and zcd.primaryrecord = 'P'
left join	pricingreferencetables.dbo.zips_with_closest_msa md
		on substring(po.destinationzip,1,5) = md.zipcode


/*****************************************************************************************************************/

-- Get base rate and PPM for MSA to MSA

update	#predictions_output
set	base_rate = ppm.ppm*po.mileage,
	ppm = ppm.ppm
from	#predictions_output po
left join	pricingreferencetables.dbo.ppm_master ppm
		on po.omsa = ppm.o_msa
		and po.dmsa = ppm.d_msa


update #predictions_output

set    base_rate = x.rate,

       ppm = x.rate*1.0/case when po.mileage < 1 then 1 else po.mileage end

from   #predictions_output po

join   PricingReferenceTables.dbo.MSA_to_MSA_Rates_by_Mileage x

              on po.omsa = x.omsa

              and po.dmsa = x.dmsa

              and po.mileage between x.maxmiles - 10 and x.maxmiles

where  po.omsa_miles = 0 and po.dmsa_miles = 0                   -- including this line prevents overriding for cases where the MSA is the CLOSEST MSA, but not actually IN the MSA




/*****************************************************************************************************************/

-- If no base rate, then apply short distance (<= 250 miles) mileage pricing and set PPM = 0

update	#predictions_output
set	base_rate = case	when po.mileage <= 10 then 100
			when po.mileage <= 20 then 115
			--when po.mileage <= 75 then 90+((po.mileage-15)/2)
			--when po.mileage <= 125 then 95+((po.mileage-20)/2)
			when po.mileage > 20 then 105+((po.mileage-15)/2) end,
	ppm = 0
from	#predictions_output po
where	po.mileage <= 250
	and po.base_rate is null


/*****************************************************************************************************************/

-- Apply Fuel Surcharge (based on fuel prices from 2 weeks ago)

update	#predictions_output
set	Fuel_Surcharge = case	when x.gas_2wa > f.fuel_baseline then (ceiling((x.gas_2wa-f.fuel_baseline)/f.fuel_tiers)*f.Fuel_surcharge)*x.base_rate
				else 0 end
from	#predictions_output x
join	pricingreferencetables.dbo.fuel_surcharge_v6 f
		on x.mileage between f.low and f.high

/*****************************************************************************************************************/

-- Apply Zipcode Tier surcharge (from FedEx's Tiers)

update	#predictions_output
set	zipcode_tier_surcharge = (x.base_rate * d.surchargep)+d.surcharged,
	zipcode_tier = zta.dtier
from	#predictions_output x
join	pricingreferencetables.dbo.zipcode_tier_assignments zta
		on substring(x.destinationzip,1,5) = zta.zip
join	pricingreferencetables.dbo.zipcode_tiers_4_v6 d
		on zta.dtier = d.tier

/*****************************************************************************************************************/

--Apply Service Level Surcharge (based on partner)

update	#predictions_output
set	ServiceLevel_Surcharge = x.base_rate*(sl.sl_surchargep)
from	#predictions_output x
join	pricingreferencetables.dbo.servicelevel_v6 sl
		on sl.partner = x.partner

/*****************************************************************************************************************/

--Apply Origin State Surcharge

update	#predictions_output
set	Stateo_surcharge = case when x.mileage > so.minmiles then (case when so.stateo_surchargeD > 0 then so.stateo_surchargeD else so.stateo_surchargeP*x.base_rate end) else 0 end
from	#predictions_output x
left join	pricingreferencetables.dbo.stateo_v6 so
		on x.originstate = so.state


/*****************************************************************************************************************/

--Apply Destination State Surcharge

update	#predictions_output
set	Stated_surcharge = case when x.mileage > sd.minmiles then (case when sd.stated_surchargeD > 0 then sd.stated_surchargeD else sd.stated_surchargeP*x.Base_Rate end) else 0 end
from	#predictions_output x
left join	pricingreferencetables.dbo.stated_v6 sd
		on x.DestinationState = sd.state

/*****************************************************************************************************************/


--Apply State->State Route Surcharge

update	#predictions_output
set	State_Route_surcharge = case when sr.surchargeD > 0 then sr.surchargeD else sr.surchargep*x.Base_Rate end
from	#predictions_output x
join	pricingreferencetables.dbo.state_route sr
		on x.originst = sr.O_st
		and x.destinationST = sr.d_st



/*****************************************************************************************************************/

-- Apply Congested Origin Zip surcharge


update	#predictions_output
set	Congestedo_Surcharge = co.congested_surcharge
from	#predictions_output x
join	pricingreferencetables.dbo.congested_zipcodes c
		on x.originzip = c.zipcode
join	pricingreferencetables.dbo.congestedo_v6 co
		on 1 = 1



/*****************************************************************************************************************/

--Apply Congested Destination Zipcode Surcharge

update	#predictions_output
set	CongestedD_Surcharge =	case	when x.congestedo_surcharge > 0 and x.mileage <= 50 then 0
				else cd.congested_surcharge end
from	#predictions_output x
join	pricingreferencetables.dbo.congested_zipcodes c
		on x.destinationzip = c.zipcode
join	pricingreferencetables.dbo.congestedd_v6 cd
		on 1 = 1



/*****************************************************************************************************************/

--Apply Weight Surcharge

update	#predictions_output
set	weight_surcharge = case	when x.totalweight > w.minweight and w.surchargep > 0 then (((x.totalweight-200)/50)*(w.surchargep)*x.Base_Rate)
			when x.totalweight > w.minweight and w.surcharged > 0 then (w.surcharged*(x.totalweight-w.minweight)/50) else 0 end
from	#predictions_output x
join	pricingreferencetables.dbo.weight_v6 w
		on 1 = 1



/*****************************************************************************************************************/

--Apply Big & Bulky Surcharge



update	#predictions_output
set	bb_surcharge = (x.Base_Rate * bb.bb_surchargep)+bb.bb_surcharged
from	#predictions_output x
join	pricingreferencetables.dbo.bb_v6 bb
		on bb.bb_rating = x.bb





/*****************************************************************************************************************/

--Apply Difficulty Surcharge

update	#predictions_output
set	difficulty_surcharge = (x.Base_Rate * d.surchargep)+d.surcharged
from	#predictions_output x
join	pricingreferencetables.dbo.difficulty_v6 d
		on d.diffidx = x.difficulty_idx


/*****************************************************************************************************************/

--Apply Mileage surcharge

update	#predictions_output
set	mileage_surcharge = m.surchargep*x.Base_Rate
from	#predictions_output x
join	pricingreferencetables.dbo.mileage_surcharge_v6 m
		on x.mileage between m.minmiles and m.maxmiles





/*****************************************************************************************************************/

-- Apply Congested Origin Zip surcharge


update	#predictions_output
set	Congestedo_Surcharge = co.congested_surcharge
from	#predictions_output x
join	pricingreferencetables.dbo.congested_zipcodes c
		on x.originzip = c.zipcode
join	pricingreferencetables.dbo.congestedo_v6 co
		on 1 = 1



/*****************************************************************************************************************/

--Apply Congested Destination Zipcode Surcharge

update	#predictions_output
set	CongestedD_Surcharge =	case	when x.congestedo_surcharge > 0 and x.mileage <= 50 then 0
				else cd.congested_surcharge end
from	#predictions_output x
join	pricingreferencetables.dbo.congested_zipcodes c
		on x.destinationzip = c.zipcode
join	pricingreferencetables.dbo.congestedd_v6 cd
		on 1 = 1



/*****************************************************************************************************************/


-- Apply OMSA Surcharge


update	#predictions_output
set	omsa_Surcharge =	case	when msa.surcharged > 0 then msa.surcharged else x.base_rate*msa.surchargep end
from	#predictions_output x
join	pricingreferencetables.dbo.omsa_surcharge msa
		on x.omsa = msa.msa



/*****************************************************************************************************************/

--Apply DMSA Surcharge


update	#predictions_output
set	dmsa_Surcharge =	case	when msa.surcharged > 0 then msa.surcharged else x.base_rate*msa.surchargep end
from	#predictions_output x
join	pricingreferencetables.dbo.dmsa_surcharge msa
		on x.dmsa = msa.msa



/*****************************************************************************************************************/

--Apply Expedited PU and DEL Surcharges


update	#predictions_output
set	expedited_pu_surcharge = case when pu.surchargep > 0 then pu.surchargep*x. base_rate else isnull(pu.surcharged,0) end
from	#predictions_output x
left join	pricingreferencetables.dbo.expedited_pu pu
		on datediff(dd,x.datecreated,x.listing_latest_pickup) between pu.PU_days_min and pu. pu_days_max



update	#predictions_output
set	expedited_del_surcharge = case when del.surchargep > 0 then del.surchargep*x. base_rate else isnull(del.surcharged,0) end
from	#predictions_output x
left join	pricingreferencetables.dbo.expedited_del del
		on datediff(dd,x.datecreated,x.listing_latest_delivery) between del.del_days_min and del.del_days_max



/*****************************************************************************************************************/


--Apply Multi-Item Discount


update	#predictions_output
set	multi_item_surcharge = x.Base_Rate*(x.totalitems-1)*(1-mid.discount)
from	#predictions_output x
join	pricingreferencetables.dbo.multi_item_discount_v6 mid
		on x.totalitems > 1


/*****************************************************************************************************************/

--Apply Surcharge for Distance to closest Orig/Dest MSAs

update	#predictions_output
set	Close_to_OMSA_Surcharge = y.surcharged
from	#predictions_output x
join	pricingreferencetables.dbo.Miles_to_MSA_surcharge y
		on x.omsa_miles between y.minmiles and y.maxmiles
where	omsa_miles > 0


update	#predictions_output
set	Close_to_DMSA_Surcharge = y.surcharged
from	#predictions_output x
join	pricingreferencetables.dbo.Miles_to_MSA_surcharge y
		on x.dmsa_miles between y.minmiles and y.maxmiles
where	dmsa_miles > 0




/*****************************************************************************************************************/

--Additional quantity Surcharge

update	#predictions_output
set	Addtl_qty_surcharge = case	when x.item1qty <= f.singleitemqty then 0
			when x.item1qty > f.singleitemqty then (ceiling(x.item1qty/f.singleitemqty)-1)*x.base_rate*f.addtl_percent end
from	#predictions_output x
left join	pricingreferencetables.dbo.furniture_indexes f
		on x.item1keyword = f.keyword




/*****************************************************************************************************************/

-- Add all Surcharges to Base Rate


update	#predictions_output
set	Rate_Engine_prediction =	isnull(base_rate,0)+isnull(fixedcost,0)+isnull(fuel_surcharge,0)+isnull(zipcode_tier_surcharge,0)+isnull(servicelevel_surcharge,0)+isnull(stateo_surcharge,0)+isnull(stated_surcharge,0)+
				isnull(state_route_surcharge,0)+isnull(congestedo_surcharge,0)+isnull(congestedd_surcharge,0)+isnull(omsa_surcharge,0)+isnull(dmsa_surcharge,0)+isnull(weight_surcharge,0)+
				isnull(bb_surcharge,0)+isnull(difficulty_surcharge,0)+isnull(mileage_surcharge,0)+isnull(expedited_pu_surcharge,0)+isnull(expedited_del_surcharge,0)+isnull(multi_item_surcharge,0)+
				isnull(Close_to_OMSA_Surcharge,0)+isnull(close_to_DMSA_Surcharge,0)+isnull(Addtl_qty_surcharge,0)


update	#predictions_output
set	toohigh = 1
from	#predictions_output po
join	pricingreferencetables.dbo.evaluation e
		on e.rating = 'Too High'
where	po.rate_engine_prediction > po.matchprice*(1+e.pct) or (po.rate_engine_prediction - po.matchprice > e.amount and e.amount > 0)


update	#predictions_output
set	toolow = 1
from	#predictions_output po
join	pricingreferencetables.dbo.evaluation e
		on e.rating = 'Too Low'
where	rate_engine_prediction < matchprice*(1-e.pct) or (matchprice - rate_engine_prediction > e.amount and e.amount > 0)


update	#predictions_output
set	good = 1
where	toohigh = 0
	and toolow = 0


/* THE WHERE STATEMENT IS FOR FINDING SPECIFIC LANES*/
select	*
from	#predictions_output po
--where po.omsa = 'Los Angeles-Riverside-Orange County, CA'
--and po.dmsa = 'Los Angeles-Riverside-Orange County, CA'
--order by DateCreated


select	case	when toohigh > 0 then 'Too high'
		when toolow > 0 then 'Too Low'
		when good > 0 then 'Good' end 'Evaluation',
	count(*) 'Shipments'
from	#predictions_output
group by	case	when toohigh > 0 then 'Too high'
		when toolow > 0 then 'Too Low'
		when good > 0 then 'Good' end



--drop table	sra.ihdpricing.rate_engine_output
--select	*
--into	sra.ihdpricing.rate_engine_output
--from	#predictions_output




/*

Select * from sra.ihd.chairish_repricing_audit


select	*
from	#predictions_output
where	packageid = 14365234

*/

/*

select	*
from	pricingreferencetables.dbo.evaluation e


update	pricingreferencetables.dbo.evaluation e
set	pct = 0.15,
	amount = 50
where	rating = 'too high'

update	pricingreferencetables.dbo.evaluation e
set	pct = 0.15,
	amount = 50
where	rating = 'too low'

*/


--Base_Rate
--Fixed_Cost
--Fuel_Surcharge
--Zipcode_Tier_Surcharge
--ServiceLevel_Surcharge
--StateO_Surcharge
--StateD_Surcharge
--State_Route_Surcharge
--CongestedO_surcharge
--CongestedD_surcharge
--OMSA_Surcharge
--DMSA_Surcharge
--Weight_Surcharge
--BB_Surcharge
--Difficulty_Surcharge
--Mileage_Surcharge
--Multi_item_Surcharge
--Expedited_PU_Surcharge
--Expedited_DEL_Surcharge
--Addtl_qty_surcharge
