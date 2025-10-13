const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function checkSchedule() {
  try {
    const { data, error } = await supabase
      .from('class_schedule')
      .select('time_slot')
      .limit(10);

    if (error) {
      console.error('Error fetching class schedule:', error);
      return;
    }

    console.log('Distinct time slots from class_schedule:', data);
  } catch (err) {
    console.error('An unexpected error occurred:', err);
  }
}

checkSchedule();

